name "keystone-server"
description "Keystone server"
run_list(
    "role[openstack-base]",
    "recipe[keystone-custom]",
    "role[os-identity]"
)
