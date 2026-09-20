// seed_ldap_roles_set2.js
//
// Roles in admin whose name is the exact DN of an AD security group.
// MongoDB grants these automatically to any $external user the LDAP
// authz query template resolves into that group. This is the live
// version of the AD-group-to-MongoDB-role mapping the whole project
// is meant to design.

var groups = [
  {
    dn: "CN=MongoDB-Admins,OU=Groups,OU=MongoDB,DC=mongolab,DC=local",
    roles: [{ role: "root", db: "admin" }]
  },
  {
    dn: "CN=MongoDB-AppDB1-ReadWrite,OU=Groups,OU=MongoDB,DC=mongolab,DC=local",
    roles: [{ role: "readWrite", db: "appdb1" }]
  },
  {
    dn: "CN=MongoDB-AppDB2-ReadOnly,OU=Groups,OU=MongoDB,DC=mongolab,DC=local",
    roles: [{ role: "read", db: "appdb2" }]
  }
];

groups.forEach(function (g) {
  db.getSiblingDB("admin").createRole({
    role: g.dn,
    privileges: [],
    roles: g.roles
  });
});

print("seed_ldap_roles_set2.js complete");