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

if node[:keystone][:api][:protocol] == "https"
  include_recipe "apache2"
  include_recipe "apache2::mod_ssl"
  include_recipe "apache2::mod_wsgi"
end

package "keystone" do
  package_name "openstack-keystone" if node.platform == "suse"
  action :install
end

if node[:keystone][:api][:protocol] == "https"
  Chef::Log.info("Configuring Keystone to use SSL via Apache2+mod_wsgi")

  # Prepare Apache2 SSL vhost template:
  template "#{node[:apache][:dir]}/sites-available/openstack-keystone.conf" do
    if node.platform == "suse"
      path "#{node[:apache][:dir]}/vhosts.d/openstack-keystone.conf"
    end
    source "keystone-apache-ssl.conf.erb"
    mode 0644
    variables(
        :user => node[:keystone][:user],
        :group => node[:keystone][:group],
        :ssl_crt_file => node[:keystone][:apache][:ssl_crt_file],
        :ssl_key_file => node[:keystone][:apache][:ssl_key_file]
    )
    if ::File.symlink?("#{node[:apache][:dir]}/sites-enabled/openstack-keystone.conf") or node.platform == "suse"
      notifies :reload, resources(:service => "apache2")
    end
  end

  apache_site "openstack-keystone.conf" do
    enable true
  end
else
  service "keystone" do
    service_name "openstack-keystone" if node.platform == "suse"
    supports :status => true, :restart => true
    action :enable
  end
end

sql_engine = node[:keystone][:sql_engine]
url_scheme = ""

Chef::Log.info("Configuring Keystone to use #{sql_engine} backend")

if sql_engine == "database"

    env_filter = " AND #{sql_engine}_config_environment:#{sql_engine}-config-#{node[:keystone][:sql_instance]}"
    sqls = search(:node, "roles:#{sql_engine}-server#{env_filter}") || []
    if sqls.length > 0
        sql = sqls[0]
        sql = node if sql.name == node.name
    else
        sql = node
    end
    include_recipe "database::client"
    backend_name = Chef::Recipe::Database::Util.get_backend_name(sql)
    include_recipe "#{backend_name}::client"
    include_recipe "#{backend_name}::python-client"

    db_provider = Chef::Recipe::Database::Util.get_database_provider(sql)
    db_user_provider = Chef::Recipe::Database::Util.get_user_provider(sql)
    privs = Chef::Recipe::Database::Util.get_default_priviledges(sql)
    url_scheme = backend_name

    ::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)
    node.set_unless['keystone']['db']['password'] = secure_password


    sql_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(sql, "admin").address if sql_address.nil?
    Chef::Log.info("Database server found at #{sql_address}")

    db_conn = { :host => sql_address,
                :username => "db_maker",
                :password => sql[sql_engine][:db_maker_password] }

    # Create the Keystone Database
    database "create #{node[:keystone][:db][:database]} database" do
        connection db_conn
        database_name node[:keystone][:db][:database]
        provider db_provider
        action :create
    end

    database_user "create keystone database user" do
        connection db_conn
        username node[:keystone][:db][:user]
        password node[:keystone][:db][:password]
        provider db_user_provider
        action :create
    end

    database_user "grant database access for keystone database user" do
        connection db_conn
        username node[:keystone][:db][:user]
        password node[:keystone][:db][:password]
        database_name node[:keystone][:db][:database]
        host sql_address
        privileges privs
        provider db_user_provider
        action :grant
    end
    sql_connection = "#{url_scheme}://#{node[:keystone][:db][:user]}:#{node[:keystone][:db][:password]}@#{sql_address}/#{node[:keystone][:db][:database]}"
elsif sql_engine == "sqlite"
    sql_connection = "sqlite:////var/lib/keystone/keystone.db"
    file "/var/lib/keystone/keystone.db" do
        owner node[:keystone][:user]
        action :create_if_missing
    end
    url_scheme = "sqlite"
else
    Chef::Log.error("Unknown sql_engine #{sql_engine}")
end


template "/etc/keystone/keystone.conf" do
    source "keystone.conf.erb"
    owner node[:keystone][:user]
    mode 0640
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
    # The service is only used if the Apache2 SSL vhost isn't configured.
    if node[:keystone][:api][:protocol] != "https"
      notifies :restart, resources(:service => "keystone"), :immediately
    end
end

# Replace the service symlink on SUSE with a symlink to /etc/init/apache2
# if SSL is enabled:
if node[:keystone][:api][:protocol] == "https"
  file "/etc/init.d/openstack-keystone" do
    action :delete
  end if ::File.exists?("/etc/init.d/openstack-keystone")
  link "/etc/init.d/openstack-keystone" do
    link_type :symbolic
    to "/etc/init.d/apache2"
  end
end

execute "keystone-manage db_sync" do
  action :run
  if node[:keystone][:api][:protocol] == "https"
    notifies :restart, resources(:service => "apache2"), :immediately
  end
end

my_ipaddress = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
pub_ipaddress = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "public").address rescue my_ipaddress

# Silly wake-up call - this is a hack
keystone_register "wakeup keystone" do
  protocol node[:keystone][:api][:protocol]
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
    protocol node[:keystone][:api][:protocol]
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
    protocol node[:keystone][:api][:protocol]
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
    protocol node[:keystone][:api][:protocol]
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
    protocol node[:keystone][:api][:protocol]
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
    protocol node[:keystone][:api][:protocol]
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
  protocol node[:keystone][:api][:protocol]
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
  protocol node[:keystone][:api][:protocol]
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
