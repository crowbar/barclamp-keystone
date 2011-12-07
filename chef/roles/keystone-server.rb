name "keystone-server"
description "Keystone server"

run_list(
  "recipe[keystone::server]",
  "recipe[keystone::monitor]"
)

