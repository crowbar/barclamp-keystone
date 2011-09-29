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
  nodes.each { |n|
    result << node_addr(n)
  }
  result
end

def node_addr(n)
  ip = Chef::Recipe::Barclamp::Inventory.get_network_by_type(n, "public").address
  ip ||= Chef::Recipe::Barclamp::Inventory.get_network_by_type(n, "admin").address
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

cfg_name = node[:keystone][:config][:environment].gsub("keystone-config-","")
nova_api_filter = "recipes:nova\\:\\:api AND nova_config_environment:nova-config-#{cfg_name}"
swift_api_filter = "recipes:swift\\:\\:proxy AND swift_config_environment:swift-config-#{cfg_name}"
glance_api_filter = "recipes:glance\\:\\:api AND glance_config_environment:glance-config-#{cfg_name}"

Chef::Log.fatal("GREG: glance_api_filter = #{glance_api_filter}")
Chef::Log.fatal("GREG: swift_api_filter = #{swift_api_filter}")
Chef::Log.fatal("GREG: nova_api_filter = #{nova_api_filter}")

nova_nodes = search(:node,nova_api_filter)
swift_nodes = search(:node,swift_api_filter)
glance_nodes = search(:node,glance_api_filter)

Chef::Log.fatal("GREG: glance_nodes = #{glance_nodes.nil? ? "NIL" : glance_nodes.inspect}")
Chef::Log.fatal("GREG: swift_nodes = #{swift_nodes.nil? ? "NIL" : swift_nodes.inspect}")
Chef::Log.fatal("GREG: nova_nodes = #{nova_nodes.nil? ? "NIL" : nova_nodes.inspect}")

nova_addrs = nodes_addresses(nova_nodes)
swift_addrs = nodes_addresses(swift_nodes)
glance_addrs = nodes_addresses(glance_nodes)

Chef::Log.fatal("GREG: glance_addrs = #{glance_addrs.nil? ? "NIL" : glance_addrs.inspect}")
Chef::Log.fatal("GREG: swift_addrs = #{swift_addrs.nil? ? "NIL" : swift_addrs.inspect}")
Chef::Log.fatal("GREG: nova_addrs = #{nova_addrs.nil? ? "NIL" : nova_addrs.inspect}")

keystone_ip = node_addr(node)

execute "keystone initial data" do
  command "/tmp/initial_data.sh"
  action :nothing
end

template "/tmp/initial_data.sh" do
  source "initial_data.sh.erb"
  mode "0755"
  owner user
  group grp
  variables ( { :nova_addrs => nova_addrs, :swift_addrs => swift_addrs, :glance_addrs => glance_addrs, :keystone_addr => keystone_ip })
  notifies :run, "execute[keystone initial data]", :immediately
end

service "keystone" do
  action [:enable, :start ]
end

