// seed_sample_data.js
//
// Enough collections and documents to give 05_databases.js real dbStats and
// listCollections output to reconcile, and, on the sharded cluster, enough
// data volume for a sharded collection to have actual chunk distribution.

db.getSiblingDB("appdb1").orders.insertMany(
  Array.from({ length: 5000 }, (_, i) => ({
    orderId: i,
    customer: "cust" + (i % 200),
    amount: Math.round(Math.random() * 10000) / 100,
    createdAt: new Date()
  }))
);

db.getSiblingDB("appdb2").reports.insertMany(
  Array.from({ length: 500 }, (_, i) => ({
    reportId: i,
    generatedAt: new Date()
  }))
);

// only meaningful when run against mongos on the sharded cluster
if (typeof sh !== "undefined") {
  try {
    sh.enableSharding("appdb1");
    sh.shardCollection("appdb1.orders", { orderId: "hashed" });
    print("sharding enabled on appdb1.orders");
  } catch (e) {
    print("sharding step skipped/failed: " + e);
  }
}

print("seed_sample_data.js complete");