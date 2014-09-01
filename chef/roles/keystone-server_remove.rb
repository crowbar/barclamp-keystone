name "keystone-server_remove"
description "Deactivate Keystone Server Role"
run_list(
  "recipe[keystone::remove_server]"
)
default_attributes()
override_attributes()
