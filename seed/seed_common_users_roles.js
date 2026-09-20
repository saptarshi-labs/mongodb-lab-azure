// seed_common_users_roles.js
//
// Creates a realistic mix of accounts and roles so the discovery scripts
// have something worth finding: an over-privileged human account, a couple
// of application service accounts scoped to one database, a custom role,
// and a genuinely built-in-role holder to trigger the over-privilege flag
// in the gap analysis.

db.getSiblingDB("admin").createUser({
  user: "dba_legacy_root",
  pwd: "ChangeMe123!",
  roles: [{ role: "root", db: "admin" }]  // intentionally over-privileged, for testing the flag
});

db.getSiblingDB("appdb1").createUser({
  user: "svc_ordersapp",
  pwd: "ChangeMe123!",
  roles: [{ role: "readWrite", db: "appdb1" }]
});

db.getSiblingDB("appdb2").createUser({
  user: "svc_reportingapp",
  pwd: "ChangeMe123!",
  roles: [{ role: "read", db: "appdb2" }]
});

db.getSiblingDB("appdb1").createRole({
  role: "custom_orders_writer",
  privileges: [
    {
      resource: { db: "appdb1", collection: "orders" },
      actions: ["find", "insert", "update"]
    }
  ],
  roles: []
});

db.getSiblingDB("appdb1").createUser({
  user: "svc_ordersapp_restricted",
  pwd: "ChangeMe123!",
  roles: [{ role: "custom_orders_writer", db: "appdb1" }]
});

db.getSiblingDB("admin").createUser({
  user: "human_saptarshi_test",
  pwd: "ChangeMe123!",
  roles: [
    { role: "readWriteAnyDatabase", db: "admin" },
    { role: "userAdminAnyDatabase", db: "admin" }
  ]
});

print("seed_common_users_roles.js complete");