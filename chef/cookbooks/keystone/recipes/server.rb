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
      :sql_idle_timeout => node[:keystone][:sql][:idle_timeout],
      :sql_min_pool_size => node[:keystone][:sql][:min_pool_size],
      :sql_max_pool_size => node[:keystone][:sql][:max_pool_size],
      :sql_pool_timeout => node[:keystone][:sql][:pool_timeout],
      :debug => node[:keystone][:debug],
      :verbose => node[:keystone][:verbose],
      :admin_token => node[:keystone][:service][:token],
      :service_api_port => node[:keystone][:api][:service_port], # Compute port
      :service_api_host => node[:keystone][:api][:service_host],
      :admin_api_port => node[:keystone][:api][:admin_port], # Auth port
      :admin_api_host => node[:keystone][:api][:admin_host],
      :api_port => node[:keystone][:api][:api_port], # public port
      :api_host => node[:keystone][:api][:api_host],
      :use_syslog => node[:keystone][:use_syslog]
    )
    notifies :restart, resources(:service => "keystone"), :immediately
end

my_ipaddress = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
pub_ipaddress = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "public").address rescue my_ipaddress

service_endpoint="http://127.0.0.1:#{node[:keystone][:api][:admin_port]}/v2.0"
keystone_parms="--token #{node[:keystone][:service][:token]} --endpoint #{service_endpoint}"

execute "keystone-manage db_sync" do
  action :run
end

# Create admin tenant
execute "Keystone: add <admin> tenant" do
  command "keystone #{keystone_parms} tenant-create --name #{node[:keystone][:admin][:tenant]}"
  action :run
  not_if "keystone #{keystone_parms} tenant-list |grep #{node[:keystone][:admin][:tenant]}"
end

# Create service tenant
execute "Keystone: add <service> tenant" do
  command "keystone #{keystone_parms} tenant-create --name #{node[:keystone][:service][:tenant]}"
  action :run
  not_if "keystone #{keystone_parms} tenant-list |grep #{node[:keystone][:service][:tenant]}"
end

# Create default tenant
execute "Keystone: add <default> tenant" do
  command "keystone #{keystone_parms} tenant-create --name #{node[:keystone][:default][:tenant]}"
  action :run
  not_if "keystone #{keystone_parms} tenant-list |grep #{node[:keystone][:default][:tenant]}"
end

# Create admin user
execute "Keystone: add <admin> user" do
  command "keystone #{keystone_parms} user-create --name=#{node[:keystone][:admin][:username]} --pass='#{node[:keystone][:admin][:password]}'"
  action :run
  not_if "keystone #{keystone_parms} user-list | grep \"| #{node[:keystone][:admin][:username]} \""
end

# Create default user
execute "Keystone: add <default> user" do
  command "keystone #{keystone_parms} user-create --name=#{node[:keystone][:default][:username]} --pass='#{node[:keystone][:default][:password]}'"
  action :run
  not_if "keystone #{keystone_parms} user-list | grep \"| #{node[:keystone][:default][:username]} \""
end

# Create roles
roles = %w[admin Member KeystoneAdmin KeystoneServiceAdmin sysadmin netadmin]
roles.each do |role|
  execute "Keystone: add #{role} role" do
    command "keystone #{keystone_parms} role-create --name=#{role}"
    action :run
    not_if "keystone #{keystone_parms} role-list | grep \"| #{role} \""
  end
end

user_roles = [ 
  [node[:keystone][:admin][:username], "admin", node[:keystone][:admin][:tenant]],
  [node[:keystone][:admin][:username], "KeystoneAdmin", node[:keystone][:admin][:tenant]],
  [node[:keystone][:admin][:username], "KeystoneServiceAdmin", node[:keystone][:admin][:tenant]],
  [node[:keystone][:admin][:username], "admin", node[:keystone][:default][:tenant]],
  [node[:keystone][:default][:username], "Member", node[:keystone][:default][:tenant]],
  [node[:keystone][:default][:username], "sysadmin", node[:keystone][:default][:tenant]],
  [node[:keystone][:default][:username], "netadmin", node[:keystone][:default][:tenant]]
]


# 
# There isn't a CLI method to determine if already done.  Just do it.
#
user_roles.each do |args|
  bash "Keystone: grant #{args[1]} role to #{args[0]} user in tenant #{args[2]}" do
    code <<EOF
MY_UID=`keystone #{keystone_parms} user-list | grep "| #{args[0]} " | awk '{ print $2 }'`
RID=`keystone #{keystone_parms} role-list | grep "| #{args[1]} " | awk '{ print $2 }'`
TID=`keystone #{keystone_parms} tenant-list | grep "| #{args[2]} " | awk '{ print $2 }'`
keystone #{keystone_parms} user-role-add --user $MY_UID --role $RID --tenant_id $TID
EOF
    action :run
  end
end


ec2_creds = [ 
  [node[:keystone][:admin][:username], node[:keystone][:admin][:tenant]],
  [node[:keystone][:admin][:username], node[:keystone][:default][:tenant]],
  [node[:keystone][:default][:username], node[:keystone][:default][:tenant]]
]

ec2_creds.each do |args|
  bash "Keystone: add EC2 credentials to #{args[0]} user on #{args[1]}" do
    code <<EOF
MY_UID=`keystone #{keystone_parms} user-list | grep "| #{args[0]} " | awk '{ print $2 }'`
TID=`keystone #{keystone_parms} tenant-list | grep "| #{args[1]} " | awk '{ print $2 }'`
keystone #{keystone_parms} ec2-credentials-create --tenant_id=$TID --user=$MY_UID
EOF
    action :run
  end
end


keystone_register "register keystone service" do
  host my_ipaddress
  port node[:keystone][:api][:admin_port]
  token node[:keystone][:service][:token]
  service_name "keystone"
  service_type "identity"
  service_description "Openstack Identity Service"
  action :add_service
end

keystone_register "register keystone service" do
  host my_ipaddress
  port node[:keystone][:api][:admin_port]
  token node[:keystone][:service][:token]
  endpoint_service "keystone"
  endpoint_region "RegionOne"
  endpoint_adminURL "http://#{my_ipaddress}:#{node[:keystone][:api][:admin_port]}/v2.0"
  endpoint_internalURL "http://#{my_ipaddress}:#{node[:keystone][:api][:service_port]}/v2.0"
  endpoint_publicURL "http://#{pub_ipaddress}:#{node[:keystone][:api][:service_port]}/v2.0"
#  endpoint_global true
#  endpoint_enabled true
  action :add_endpoint_template
end

node[:keystone][:monitor] = {} if node[:keystone][:monitor].nil?
node[:keystone][:monitor][:svcs] = [] if node[:keystone][:monitor][:svcs].nil?
node[:keystone][:monitor][:svcs] <<["keystone"]
node.save
