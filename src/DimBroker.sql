-- Databricks notebook source
INSERT INTO ${catalog}.${schema}.DimBroker (brokerid, managerid, firstname, lastname, middleinitial, branch, office, phone, iscurrent, batchid, effectivedate, enddate)
SELECT
  employeeid brokerid,
  managerid,
  employeefirstname firstname,
  employeelastname lastname,
  employeemi middleinitial,
  employeebranch branch,
  employeeoffice office,
  employeephone phone,
  true iscurrent,
  1 batchid,
  (SELECT min(to_date(datevalue)) as effectivedate FROM ${catalog}.${schema}.DimDate) effectivedate,
  date('9999-12-31') enddate
FROM ${catalog}.${schema}_stage.v_HR
WHERE employeejobcode = 314;