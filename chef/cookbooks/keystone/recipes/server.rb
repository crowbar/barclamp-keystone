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

execute "Fix Bug lp:865448" do
  command "sed -i 's/path.abspath(sys.argv\[0\])/path.dirname(__file__)/g' /usr/share/pyshared/keystone/controllers/version.py"
  action :run
end

service "keystone" do
  supports :status => true, :restart => true
  action :enable
end

node.set_unless['keystone']['db']['password'] = secure_password

if node[:keystone][:sql_engine] == "mysql"
    Chef::Log.info("Configuring Keystone to use MySQL backend")

    include_recipe "mysql::client"

    package "python-mysqldb" do
        action :install
    end

    mysqls = search(:node, "recipes:mysql\\:\\:server") || []
    if mysqls.length > 0
        mysql = mysqls[0]
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

debug = true
verbose = true

template "/etc/keystone/keystone.conf" do
    source "keystone.conf.erb"
    mode "0644"
    # owner user
    # group grp
    variables(
      :sql_connection => sql_connection,
      :debug => debug,
      :verbose => verbose
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

execute "Keystone: grant ServiceAdmin role to <admin> user" do
  # command syntax: role grant 'role' 'user' 'tenant (optional)'
  command "keystone-manage role grant Admin #{node[:keystone][:admin][:username]}"
  action :run
end

execute "Keystone: grant Admin role to <admin> user for <default> tenant" do
  # command syntax: role grant 'role' 'user' 'tenant (optional)'
  command "keystone-manage role grant Admin #{node[:keystone][:admin][:username]} #{node[:keystone][:default][:tenant]}"
  action :run
  not_if "keystone-manage role list #{node[:keystone][:default][:tenant]}|grep Admin"
end

my_ipaddress = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address

keystone_register "register keystone service" do
  host my_ipaddress
  token node[:keystone][:admin][:token]
  service_name "identity"
  service_description "Openstack Identity Service"
  action :add_service
end


keystone_register "register keystone service" do
  host my_ipaddress
  token node[:keystone][:admin][:token]
  endpoint_service "identity"
  endpoint_region "RegionOne"
  endpoint_adminURL "http://#{my_ipaddress}:5001/v2.0"
  endpoint_internalURL "http://#{my_ipaddress}:5000/v2.0"
  endpoint_publicURL "http://#{my_ipaddress}:5000/v2.0"
#  endpoint_global true
#  endpoint_enabled true
  action :add_endpoint_template
end

#node[:keystone][:monitor][:svcs] <<["keystone-server"]
node.save
