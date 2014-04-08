case node["platform"]
when "suse", "redhat", "centos"
  default["keystone"]["services"] = {
    "server" => ["openstack-keystone"]
  }
end
