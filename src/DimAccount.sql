-- Databricks notebook source
INSERT INTO ${catalog}.${schema}.DimAccount (
  accountid,
  sk_brokerid,
  sk_customerid,
  accountdesc,
  TaxStatus,
  status,
  iscurrent,
  batchid,
  effectivedate,
  enddate
) 
WITH account AS (
  SELECT
    accountid,
    customerid,
    accountdesc,
    taxstatus,
    brokerid,
    status,
    update_ts,
    1 batchid
  FROM
    ${catalog}.${schema}_stage.CustomerMgmt c
  WHERE
    ActionType NOT IN ('UPDCUST', 'INACT')
  UNION ALL
  SELECT
    accountid,
    a.ca_c_id customerid,
    accountDesc,
    TaxStatus,
    a.ca_b_id brokerid,
    st_name as status,
    TIMESTAMP(bd.batchdate) update_ts,
    a.batchid
  FROM
    ${catalog}.${schema}_stage.v_accountincremental a
    JOIN ${catalog}.${schema}.BatchDate bd ON a.batchid = bd.batchid
    JOIN ${catalog}.${schema}.StatusType st ON a.CA_ST_ID = st.st_id
),
account_final AS (
  SELECT
    accountid,
    customerid,
    coalesce(
      accountdesc,
      last_value(accountdesc) IGNORE NULLS OVER (
        PARTITION BY accountid
        ORDER BY update_ts
      )
    ) accountdesc,
    coalesce(
      taxstatus,
      last_value(taxstatus) IGNORE NULLS OVER (
        PARTITION BY accountid
        ORDER BY update_ts
      )
    ) taxstatus,
    coalesce(
      brokerid,
      last_value(brokerid) IGNORE NULLS OVER (
        PARTITION BY accountid
        ORDER BY update_ts
      )
    ) brokerid,
    coalesce(
      status,
      last_value(status) IGNORE NULLS OVER (
        PARTITION BY accountid
        ORDER BY update_ts
      )
    ) status,
    date(update_ts) effectivedate,
    nvl(
      lead(date(update_ts)) OVER (
        PARTITION BY accountid
        ORDER BY update_ts
      ),
      date('9999-12-31')
    ) enddate,
    batchid
  FROM account a
),
account_cust_updates AS (
  SELECT
    a.* except(effectivedate, enddate, customerid),
    c.sk_customerid,
    if(
      a.effectivedate < c.effectivedate,
      c.effectivedate,
      a.effectivedate
    ) effectivedate,
    if(a.enddate > c.enddate, c.enddate, a.enddate) enddate
  FROM account_final a
  FULL OUTER JOIN ${catalog}.${schema}_stage.DimCustomerStg c 
    ON a.customerid = c.customerid
    AND c.enddate > a.effectivedate
    AND c.effectivedate < a.enddate
  WHERE a.effectivedate < a.enddate
)
SELECT
  a.accountid,
  b.sk_brokerid,
  a.sk_customerid,
  a.accountdesc,
  a.TaxStatus,
  a.status,
  if(a.enddate = date('9999-12-31'), true, false) iscurrent,
  a.batchid,
  a.effectivedate,
  a.enddate
FROM account_cust_updates a
JOIN ${catalog}.${schema}.DimBroker b 
  ON a.brokerid = b.brokerid