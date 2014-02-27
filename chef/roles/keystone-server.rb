# -*- encoding : utf-8 -*-
name "keystone-server"
description "Keystone server"

run_list(
  "recipe[keystone::server]",
  "recipe[keystone::monitor]"
)

