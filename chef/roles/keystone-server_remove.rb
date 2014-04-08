name "keystone-server_remove"
description "Deactivate Keystone Server Role services"
run_list(
  "recipe[keystone::deactivate_server]"
)
default_attributes()
override_attributes()
