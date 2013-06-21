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

#
# Creating virtualenv for @cookbook_name and install pfs_deps with pp
#

keystone_path = "/opt/keystone"
venv_path = node[:keystone][:use_virtualenv] ? "#{keystone_path}/.venv" : nil
venv_prefix = node[:keystone][:use_virtualenv] ? ". #{venv_path}/bin/activate &&" : nil

unless node[:keystone][:use_gitrepo]

  package "keystone" do
    package_name "openstack-keystone" if node.platform == "suse"
    action :install
  end

else


  pfs_and_install_deps @cookbook_name do
    virtualenv venv_path
    path keystone_path
    wrap_bins [ "keystone-manage", "keystone" ]
  end

  if node[:keystone][:frontend]=='native'
    link_service node[:keystone][:service_name] do
      #TODO: fix for generate templates in virtualenv
      virtualenv venv_path
      bin_name "keystone-all"
    end
  end

  create_user_and_dirs(@cookbook_name)

  execute "cp_policy.json" do
    command "cp #{keystone_path}/etc/policy.json /etc/keystone/"
    creates "/etc/keystone/policy.json"
  end
end

if node[:keystone][:frontend]=='native'
  service "keystone" do
    service_name node[:keystone][:service_name]
    supports :status => true, :restart => true
    action :enable
  end
elsif node[:keystone][:frontend]=='apache'

  service "keystone" do
    service_name node[:keystone][:service_name]
    supports :status => true, :restart => true
    action [ :disable, :stop ]
  end

  include_recipe "apache2"
  include_recipe "apache2::mod_wsgi"
  include_recipe "apache2::mod_rewrite"


  directory "/usr/lib/cgi-bin/keystone/" do
    owner node[:keystone][:user]
    mode 0755
    action :create
    recursive true
  end

  template "/usr/lib/cgi-bin/keystone/main" do
    source "keystone_wsgi_bin.py.erb"
    mode 0755
    variables(
      :venv => node[:keystone][:use_virtualenv],
      :venv_path => venv_path
    )
  end

  template "/usr/lib/cgi-bin/keystone/admin" do
    source "keystone_wsgi_bin.py.erb"
    mode 0755
    variables(
      :venv => node[:keystone][:use_virtualenv],
      :venv_path => venv_path
    )
  end

  apache_site "000-default" do
    enable false
  end

  template "/etc/apache2/sites-available/keystone.conf" do
    source "apache_keystone.conf.erb"
    variables(
      :admin_api_port => node[:keystone][:api][:admin_port], # Auth port
      :admin_api_host => node[:keystone][:api][:admin_host],
      :api_port => node[:keystone][:api][:api_port], # public port
      :api_host => node[:keystone][:api][:api_host],
      :processes => 3,
      :venv => node[:keystone][:use_virtualenv],
      :venv_path => venv_path,
      :threads => 10
    )
    notifies :restart, resources(:service => "apache2"), :immediately
  end

  apache_site "keystone.conf" do
    enable true
  end
end

env_filter = " AND database_config_environment:database-config-#{node[:keystone][:database_instance]}"
sqls = search(:node, "roles:database-server#{env_filter}") || []
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
            :password => sql["database"][:db_maker_password] }

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
    host '%'
    provider db_user_provider
    action :create
end

database_user "grant database access for keystone database user" do
    connection db_conn
    username node[:keystone][:db][:user]
    password node[:keystone][:db][:password]
    database_name node[:keystone][:db][:database]
    host '%'
    privileges privs
    provider db_user_provider
    action :grant
end
sql_connection = "#{url_scheme}://#{node[:keystone][:db][:user]}:#{node[:keystone][:db][:password]}@#{sql_address}/#{node[:keystone][:db][:database]}"


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
      :use_syslog => node[:keystone][:use_syslog],
      :token_format => node[:keystone][:token_format],
      :frontend => node[:keystone][:frontend]
    )
    if node[:keystone][:frontend]=='native'
      notifies :restart, resources(:service => "keystone"), :immediately
    elsif node[:keystone][:frontend]=='apache'
      notifies :restart, resources(:service => "apache2"), :immediately
    end
end

execute "keystone-manage db_sync" do
  command "#{venv_prefix}keystone-manage db_sync"
  action :run
end

if node[:keystone][:token_format] == "PKI"
  execute "keystone-manage pki_setup" do
    command "keystone-manage pki_setup ; chown #{node[:keystone][:user]} -R /etc/keystone/ssl/"
    action :run
  end
end unless node.platform == "suse"

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
keystone_register "register keystone endpoint" do
  protocol node[:keystone][:api][:protocol]
  host my_ipaddress
  port node[:keystone][:api][:admin_port]
  token node[:keystone][:service][:token]
  endpoint_service "keystone"
  endpoint_region "RegionOne"
  endpoint_publicURL "#{node[:keystone][:api][:protocol]}://#{pub_ipaddress}:#{node[:keystone][:api][:service_port]}/v2.0"
  endpoint_adminURL "#{node[:keystone][:api][:protocol]}://#{my_ipaddress}:#{node[:keystone][:api][:admin_port]}/v2.0"
  endpoint_internalURL "#{node[:keystone][:api][:protocol]}://#{my_ipaddress}:#{node[:keystone][:api][:service_port]}/v2.0"
#  endpoint_global true
#  endpoint_enabled true
  action :add_endpoint_template
end

node[:keystone][:monitor] = {} if node[:keystone][:monitor].nil?
node[:keystone][:monitor][:svcs] = [] if node[:keystone][:monitor][:svcs].nil?
node[:keystone][:monitor][:svcs] << ["keystone"] if node[:keystone][:monitor][:svcs].empty?
node.save
