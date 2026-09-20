# mongodb-lab-azure

Azure lab for validating the mongodb-enterprise-premigration-discovery
toolkit against real topologies: standalone, 3-node replica set, and a
sharded cluster, duplicated as Set1 (local SCRAM auth) and Set2 (external
auth against an AD/LDAP domain controller).

See ops/ for run order. Never commit state/ or terraform.tfstate — both
carry live credentials.