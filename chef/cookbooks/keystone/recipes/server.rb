user = node[:openstack][:keystone][:user]
uid = node[:openstack][:keystone][:uid]
grp = node[:openstack][:keystone][:group]

user node[:openstack][:keystone][:user] do
   uid uid
   group grp
   home "/home/keystone"
end

package "keystone"

%w{python-pastedeploy python-eventlet python-routes python-sqlalchemy}.each { |pkg|
  package pkg
}

def python_truth(v)
  v ? "True" : "False"
end

def nodes_addresses(nodes)
  result = []
  nodes..each { |n|
    result << node_addr(n)
  }
end

def node_addr(n)
  ip  = Chef::Recipe::Barclamp::Inventory.get_network_by_type(n, "public").address
  ip  ||= Chef::Recipe::Barclamp::Inventory.get_network_by_type(n, "admin").address
  ip
end

debug = python_truth(node[:openstack][:keystone][:debug])

template "/etc/keystone/keystone.conf" do
    source "keystone.conf.erb"
    mode "0644"
    owner user
    group grp
    variables ( { :debug => debug, :verbose => debug })
end


cfg_name = node[:keystone][:config][:environment]
nova_api_filter = "recipes:nova-api AND nova_config_environment: #{cfg_name}"
swift_api_filter = "recipes:[swift-proxy TO swift-proxy-acct]  AND swift_config_environment: #{cfg_name}"
glance_api_filter = "recipes:glance\:\:api AND glance_config_environment: #{cfg_name}"

nova_nodes = search(:node,nova_api_filter)
swift_nodes = search(:node,nova_api_filter)
glance_nodes = search(:node,nova_api_filter)

nova_addrs = nodes_addresses(nova_nodes)
swift_addrs = nodes_addresses(swift_nodes)
glance_addrs = nodes_addresses(glance_nodes)

keystone_ip = node_addr(node)

template "/home/keystone" do
  source "initial_data.sh.erb"
  mode "0644"
  owner user
  group grp
  variables ( { :nova_addrs => nova_addrs, :swift_addrs => swift_addrs, :glance_addrs => glance_addrs, :keystone_addr => keystone_ip })
end

      
service "keystone" do
  action [:enable, :start ]
end



