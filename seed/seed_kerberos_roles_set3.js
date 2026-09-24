// seed_kerberos_roles_set3.js
// Run against Set3's admin/appdb1/appdb2 entry points after
// 03_configure_kerberos.ps1 has created the AD accounts below and
// distributed keytabs are working end to end.

db.getSiblingDB("$external").createUser({
  user: "svc_ordersapp_set3@MONGOLAB.LOCAL",
  roles: [{ role: "readWrite", db: "appdb1" }]
});

db.getSiblingDB("$external").createUser({
  user: "svc_reportingapp_set3@MONGOLAB.LOCAL",
  roles: [{ role: "read", db: "appdb2" }]
});

db.getSiblingDB("$external").createUser({
  user: "human_saptarshi_test_set3@MONGOLAB.LOCAL",
  roles: [{ role: "readWriteAnyDatabase", db: "admin" }, { role: "userAdminAnyDatabase", db: "admin" }]
});