# Copyright 2011 Dell, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package "keystone" do
  action :install
end

service "keystone" do
  supports :status => true, :restart => true
  action :enable
end

::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)

node.set_unless['keystone']['db']['password'] = secure_password

if node[:keystone][:sql_engine] == "mysql"
    Chef::Log.info("Configuring Keystone to use MySQL backend")

    include_recipe "mysql::client"

    package "python-mysqldb" do
        action :install
    end

    env_filter = " AND mysql_config_environment:mysql-config-#{node[:keystone][:mysql_instance]}"
    mysqls = search(:node, "roles:mysql-server#{env_filter}") || []
    if mysqls.length > 0
        mysql = mysqls[0]
        mysql = node if mysql.name == node.name
    else
        mysql = node
    end

    mysql_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(mysql, "admin").address if mysql_address.nil?
    Chef::Log.info("Mysql server found at #{mysql_address}")
    
    # Create the Keystone Database
    mysql_database "create #{node[:keystone][:db][:database]} database" do
        host    mysql_address
        username "db_maker"
        password mysql[:mysql][:db_maker_password]
        database node[:keystone][:db][:database]
        action :create_db
    end

    mysql_database "create dashboard database user" do
        host    mysql_address
        username "db_maker"
        password mysql[:mysql][:db_maker_password]
        database node[:keystone][:db][:database]
        action :query
        sql "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER on #{node[:keystone][:db][:database]}.* to '#{node[:keystone][:db][:user]}'@'%' IDENTIFIED BY '#{node[:keystone][:db][:password]}';"
    end
    sql_connection = "mysql://#{node[:keystone][:db][:user]}:#{node[:keystone][:db][:password]}@#{mysql_address}/#{node[:keystone][:db][:database]}"
elsif node[:keystone][:sql_engine] == "sqlite"
    Chef::Log.info("Configuring Keystone to use SQLite backend")
    sql_connection = "sqlite:////var/lib/keystone/keystone.db"
end

template "/etc/keystone/keystone.conf" do
    source "keystone.conf.erb"
    mode "0644"
    variables(
      :sql_connection => sql_connection,
      :debug => node[:keystone][:debug],
      :verbose => node[:keystone][:verbose],
      :service_api_port => node[:keystone][:api][:service_port],
      :admin_api_port => node[:keystone][:api][:admin_port]
    )
    notifies :restart, resources(:service => "keystone"), :immediately
end

# Create default tenant
execute "Keystone: add <default> tenant" do
  command "keystone-manage tenant add #{node[:keystone][:default][:tenant]}"
  action :run
  not_if "keystone-manage tenant list|grep #{node[:keystone][:default][:tenant]}"
end

# Create admin user
execute "Keystone: add <admin> user" do
  command "keystone-manage user add #{node[:keystone][:admin][:username]} #{node[:keystone][:admin][:password]} #{node[:keystone][:default][:tenant]}"
  action :run
  not_if "keystone-manage user list|grep #{node[:keystone][:admin][:username]}"
end

# Create admin token
execute "Keystone: add <admin> user token" do
  command "keystone-manage token add #{node[:keystone][:admin][:token]} #{node[:keystone][:admin][:username]} #{node[:keystone][:default][:tenant]} #{node[:keystone][:admin]['token-expiration']}"
  action :run
  not_if "keystone-manage token list | grep #{node[:keystone][:admin][:token]}"
end

# Create default user
execute "Keystone: add <default> user" do
  command "keystone-manage user add #{node[:keystone][:default][:username]} #{node[:keystone][:default][:password]} #{node[:keystone][:default][:tenant]}"
  action :run
  not_if "keystone-manage user list|grep #{node[:keystone][:default][:username]}"
end

# Create Admin role
execute "Keystone: add ServiceAdmin role" do
  command "keystone-manage role add Admin"
  action :run
  not_if "keystone-manage role list|grep Admin"
end

# Create Member role
execute "Keystone: add Member role" do
  command "keystone-manage role add Member"
  action :run
  not_if "keystone-manage role list|grep Member"
end

# Hack since grant ServiceAdmin role call is not idempotent
file "/var/lock/thisiswhywecanthavenicethings.lock" do
  owner "root"
  group "root"
  action :nothing
end

execute "Keystone: grant ServiceAdmin role to <admin> user" do
  # This command is not idempotent, there is no way to verify if this has
  # been created before via keystone-manage
  #
  # command syntax: role grant 'role' 'user' 'tenant (optional)'
  command "keystone-manage role grant Admin #{node[:keystone][:admin][:username]}"
  action :run
  notifies :touch, resources(:file => "/var/lock/thisiswhywecanthavenicethings.lock"), :immediately
  not_if do File.exists?("/var/lock/thisiswhywecanthavenicethings.lock") end 
end

execute "Keystone: grant Admin role to <admin> user for <default> tenant" do
  # command syntax: role grant 'role' 'user' 'tenant (optional)'
  command "keystone-manage role grant Admin #{node[:keystone][:admin][:username]} #{node[:keystone][:default][:tenant]}"
  action :run
  not_if "keystone-manage role list #{node[:keystone][:default][:tenant]}|grep Admin"
end

execute "Keystone: grant Member role to <default> user for <default> tenant" do
  # command syntax: role grant 'role' 'user' 'tenant (optional)'
  command "keystone-manage role grant Member #{node[:keystone][:default][:username]} #{node[:keystone][:default][:tenant]}"
  action :run
  not_if "keystone-manage role list #{node[:keystone][:default][:tenant]}|grep Member"
end

my_ipaddress = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address

keystone_register "register keystone service" do
  host my_ipaddress
  token node[:keystone][:admin][:token]
  service_name "keystone"
  service_type "identity"
  service_description "Openstack Identity Service"
  action :add_service
end


keystone_register "register keystone service" do
  host my_ipaddress
  token node[:keystone][:admin][:token]
  endpoint_service "keystone"
  endpoint_region "RegionOne"
  endpoint_adminURL "http://#{my_ipaddress}:#{node[:keystone][:api][:admin_port]}/v2.0"
  endpoint_internalURL "http://#{my_ipaddress}:#{node[:keystone][:api][:service_port]}/v2.0"
  endpoint_publicURL "http://#{my_ipaddress}:#{node[:keystone][:api][:service_port]}/v2.0"
#  endpoint_global true
#  endpoint_enabled true
  action :add_endpoint_template
end

#node[:keystone][:monitor][:svcs] <<["keystone-server"]
node.save
