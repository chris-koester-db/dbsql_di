-- Databricks notebook source
INSERT INTO ${catalog}.${schema}.DimCompany (
  companyid, 
  status, 
  name, 
  industry, 
  sprating, 
  islowgrade, 
  ceo, 
  addressline1, 
  addressline2, 
  postalcode, 
  city, 
  stateprov, 
  country, 
  description, 
  foundingdate, 
  iscurrent, 
  batchid, 
  effectivedate, 
  enddate
)
WITH cmp as (
  SELECT
    try_to_timestamp(substring(value, 1, 15), 'yyyyMMdd-HHmmss') AS PTS,
    trim(substring(value, 19, 60)) AS CompanyName,
    trim(substring(value, 79, 10)) AS CIK,
    trim(substring(value, 89, 4)) AS Status,
    trim(substring(value, 93, 2)) AS IndustryID,
    trim(substring(value, 95, 4)) AS SPrating,
    to_date(try_to_timestamp(substring(value, 99, 8), 'yyyyMMdd')) AS FoundingDate,
    trim(substring(value, 107, 80)) AS AddrLine1,
    trim(substring(value, 187, 80)) AS AddrLine2,
    trim(substring(value, 267, 12)) AS PostalCode,
    trim(substring(value, 279, 25)) AS City,
    trim(substring(value, 304, 20)) AS StateProvince,
    trim(substring(value, 324, 24)) AS Country,
    trim(substring(value, 348, 46)) AS CEOname,
    trim(substring(value, 394, 150)) AS Description
  FROM ${catalog}.${schema}_stage.FinWire
  WHERE rectype = 'CMP'
)
SELECT 
  * 
FROM (
  SELECT
    cast(cik as BIGINT) companyid,
    st.st_name status,
    companyname name,
    ind.in_name industry,
    if(
      SPrating IN ('AAA','AA','AA+','AA-','A','A+','A-','BBB','BBB+','BBB-','BB','BB+','BB-','B','B+','B-','CCC','CCC+','CCC-','CC','C','D'), 
      SPrating, 
      cast(null as string)) sprating, 
    CASE
      WHEN SPrating IN ('AAA','AA','A','AA+','A+','AA-','A-','BBB','BBB+','BBB-') THEN false
      WHEN SPrating IN ('BB','B','CCC','CC','C','D','BB+','B+','CCC+','BB-','B-','CCC-') THEN true
      ELSE cast(null as boolean)
      END as islowgrade, 
    ceoname ceo,
    addrline1 addressline1,
    addrline2 addressline2,
    postalcode,
    city,
    stateprovince stateprov,
    country,
    description,
    foundingdate,
    nvl2(lead(pts) OVER (PARTITION BY cik ORDER BY pts), true, false) iscurrent,
    1 batchid,
    date(pts) effectivedate,
    coalesce(
      lead(date(pts)) OVER (PARTITION BY cik ORDER BY pts),
      cast('9999-12-31' as date)) enddate
  FROM cmp
  JOIN ${catalog}.${schema}.StatusType st ON cmp.status = st.st_id
  JOIN ${catalog}.${schema}.Industry ind ON cmp.industryid = ind.in_id
)
where effectivedate < enddate;