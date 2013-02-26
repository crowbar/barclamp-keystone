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

unless node[:keystone][:use_gitrepo]
  package "keystone" do
    package_name "openstack-keystone" if node.platform == "suse"
    action :install
  end
else
  keystone_path = "/opt/keystone"
  pfs_and_install_deps(@cookbook_name)
  link_service @cookbook_name do
    bin_name "keystone-all"
  end
  create_user_and_dirs(@cookbook_name) 
  execute "cp_policy.json" do
    command "cp #{keystone_path}/etc/policy.json /etc/keystone"
    creates "/etc/keystone/policy.json"
  end
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
    file "/var/lib/keystone/keystone.db" do
        owner node[:keystone][:user]
        action :create_if_missing
    end
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
      :use_syslog => node[:keystone][:use_syslog],
      :signing => node[:keystone][:signing]
    )
    notifies :restart, resources(:service => "keystone"), :immediately
end

execute "keystone-manage db_sync" do
  action :run
end

if node[:keystone][:signing]=="PKI"
  execute "keystone-manage pki_setup" do
    command "keystone-manage pki_setup ; chown keystone -R /etc/keystone/ssl/"
    action :run
  end
end

my_ipaddress = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
pub_ipaddress = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "public").address rescue my_ipaddress

# Silly wake-up call - this is a hack
keystone_register "wakeup keystone" do
  host my_ipaddress
  port node[:keystone][:api][:admin_port]
  token node[:keystone][:service][:token]
  action :wakeup
end

# Create tenants
[ node[:keystone][:admin][:tenant], 
  node[:keystone][:service][:tenant], 
  node[:keystone][:default][:tenant] 
].each do |tenant|
  keystone_register "add default #{tenant} tenant" do
    host my_ipaddress
    port node[:keystone][:api][:admin_port]
    token node[:keystone][:service][:token]
    tenant_name tenant
    action :add_tenant
  end
end

# Create users
[ [ node[:keystone][:admin][:username], node[:keystone][:admin][:password], node[:keystone][:admin][:tenant] ],
  [ node[:keystone][:default][:username], node[:keystone][:default][:password], node[:keystone][:default][:tenant] ]
].each do |user_data|
  keystone_register "add default #{user_data[0]} user" do
    host my_ipaddress
    port node[:keystone][:api][:admin_port]
    token node[:keystone][:service][:token]
    user_name user_data[0]
    user_password user_data[1]
    tenant_name user_data[2]
    action :add_user
  end
end


# Create roles
roles = %w[admin Member KeystoneAdmin KeystoneServiceAdmin sysadmin netadmin]
roles.each do |role|
  keystone_register "add default #{role} role" do
    host my_ipaddress
    port node[:keystone][:api][:admin_port]
    token node[:keystone][:service][:token]
    role_name role
    action :add_role
  end
end

# Create Access info
user_roles = [ 
  [node[:keystone][:admin][:username], "admin", node[:keystone][:admin][:tenant]],
  [node[:keystone][:admin][:username], "KeystoneAdmin", node[:keystone][:admin][:tenant]],
  [node[:keystone][:admin][:username], "KeystoneServiceAdmin", node[:keystone][:admin][:tenant]],
  [node[:keystone][:admin][:username], "admin", node[:keystone][:default][:tenant]],
  [node[:keystone][:default][:username], "Member", node[:keystone][:default][:tenant]],
  [node[:keystone][:default][:username], "sysadmin", node[:keystone][:default][:tenant]],
  [node[:keystone][:default][:username], "netadmin", node[:keystone][:default][:tenant]]
]
user_roles.each do |args|
  keystone_register "add default #{args[2]}:#{args[0]} -> #{args[1]} role" do
    host my_ipaddress
    port node[:keystone][:api][:admin_port]
    token node[:keystone][:service][:token]
    user_name args[0]
    role_name args[1]
    tenant_name args[2]
    action :add_access
  end
end


# Create EC2 creds for our users
ec2_creds = [ 
  [node[:keystone][:admin][:username], node[:keystone][:admin][:tenant]],
  [node[:keystone][:admin][:username], node[:keystone][:default][:tenant]],
  [node[:keystone][:default][:username], node[:keystone][:default][:tenant]]
]
ec2_creds.each do |args|
  keystone_register "add default ec2 creds for #{args[1]}:#{args[0]}" do
    host my_ipaddress
    port node[:keystone][:api][:admin_port]
    token node[:keystone][:service][:token]
    user_name args[0]
    tenant_name args[1]
    action :add_ec2
  end
end

# Create keystone service
keystone_register "register keystone service" do
  host my_ipaddress
  port node[:keystone][:api][:admin_port]
  token node[:keystone][:service][:token]
  service_name "keystone"
  service_type "identity"
  service_description "Openstack Identity Service"
  action :add_service
end

# Create keystone endpoint
keystone_register "register keystone service" do
  host my_ipaddress
  port node[:keystone][:api][:admin_port]
  token node[:keystone][:service][:token]
  endpoint_service "keystone"
  endpoint_region "RegionOne"
  endpoint_publicURL "http://#{pub_ipaddress}:#{node[:keystone][:api][:service_port]}/v2.0"
  endpoint_adminURL "http://#{my_ipaddress}:#{node[:keystone][:api][:admin_port]}/v2.0"
  endpoint_internalURL "http://#{my_ipaddress}:#{node[:keystone][:api][:service_port]}/v2.0"
#  endpoint_global true
#  endpoint_enabled true
  action :add_endpoint_template
end

node[:keystone][:monitor] = {} if node[:keystone][:monitor].nil?
node[:keystone][:monitor][:svcs] = [] if node[:keystone][:monitor][:svcs].nil?
node[:keystone][:monitor][:svcs] << ["keystone"] if node[:keystone][:monitor][:svcs].empty?
node.save
