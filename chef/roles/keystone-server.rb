name "keystone-server"
description "Keystone server"
run_list(
    "role[os-base]",
    "recipe[keystone-custom]",
    "recipe[openstack-identity::server]",
    "recipe[openstack-identity::registration]"
)
