-- Databricks notebook source
INSERT INTO ${catalog}.${schema}.DimSecurity (
  symbol,
  issue,
  status,
  name,
  exchangeid,
  sk_companyid,
  sharesoutstanding,
  firsttrade,
  firsttradeonexchange,
  dividend,
  iscurrent,
  batchid,
  effectivedate,
  enddate
)
WITH SEC as (
  SELECT
    date(to_timestamp(substring(value, 1, 15), 'yyyyMMdd-HHmmss')) AS effectivedate,
    trim(substring(value, 19, 15)) AS Symbol,
    trim(substring(value, 34, 6)) AS issue,
    trim(substring(value, 40, 4)) AS Status,
    trim(substring(value, 44, 70)) AS Name,
    trim(substring(value, 114, 6)) AS exchangeid,
    cast(substring(value, 120, 13) as BIGINT) AS sharesoutstanding,
    to_date(substring(value, 133, 8), 'yyyyMMdd') AS firsttrade,
    to_date(substring(value, 141, 8), 'yyyyMMdd') AS firsttradeonexchange,
    cast(substring(value, 149, 12) AS DOUBLE) AS Dividend,
    trim(substring(value, 161, 60)) AS conameorcik
  FROM ${catalog}.${schema}_stage.FinWire
  WHERE rectype = 'SEC'
),
dc as (
  SELECT 
    sk_companyid,
    name conameorcik,
    EffectiveDate,
    EndDate
  FROM ${catalog}.${schema}.DimCompany
  UNION ALL
  SELECT 
    sk_companyid,
    cast(companyid as string) conameorcik,
    EffectiveDate,
    EndDate
  FROM ${catalog}.${schema}.DimCompany
),
SEC_prep AS (
  SELECT 
    SEC.* except(Status, conameorcik),
    nvl(string(try_cast(conameorcik as bigint)), conameorcik) conameorcik,
    s.ST_NAME as status,
    coalesce(
      lead(effectivedate) OVER (
        PARTITION BY symbol
        ORDER BY effectivedate),
      date('9999-12-31')
    ) enddate
  FROM SEC
  JOIN ${catalog}.${schema}.StatusType s 
    ON s.ST_ID = SEC.status
),
SEC_final AS (
  SELECT 
    SEC.Symbol,
    SEC.issue,
    SEC.status,
    SEC.Name,
    SEC.exchangeid,
    dc.sk_companyid,
    SEC.sharesoutstanding,
    SEC.firsttrade,
    SEC.firsttradeonexchange,
    SEC.Dividend,
    if(SEC.effectivedate < dc.effectivedate, dc.effectivedate, SEC.effectivedate) effectivedate,
    if(SEC.enddate > dc.enddate, dc.enddate, SEC.enddate) enddate
  FROM SEC_prep SEC
  JOIN dc 
  ON
    SEC.conameorcik = dc.conameorcik 
    AND SEC.EffectiveDate < dc.EndDate
    AND SEC.EndDate > dc.EffectiveDate
)
SELECT 
  Symbol,
  issue,
  status,
  Name,
  exchangeid,
  sk_companyid,
  sharesoutstanding,
  firsttrade,
  firsttradeonexchange,
  Dividend,
  if(enddate = date('9999-12-31'), True, False) iscurrent,
  1 batchid,
  effectivedate,
  enddate
FROM SEC_final
WHERE effectivedate < enddate;