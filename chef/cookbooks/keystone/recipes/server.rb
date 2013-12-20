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


unless node[:keystone][:use_gitrepo]

  package "keystone" do
    package_name "openstack-keystone" if %w(redhat centos suse).include?(node.platform)
    action :install
  end

  if %w(redhat centos).include?(node.platform)
    #pastedeploy is not installed properly by yum, here is workaround
    bash "fix_broken_pastedeploy" do
      not_if "echo 'from paste import deploy' | python -"
      code <<-EOH
        paste_dir=`echo 'import paste; print paste.__path__[0]' | python -`
        ln -s ${paste_dir}/../PasteDeploy*/paste/deploy ${paste_dir}/
      EOH
    end
  end

else
  keystone_path = "/opt/keystone"
  venv_path = node[:keystone][:use_virtualenv] ? "#{keystone_path}/.venv" : nil
  venv_prefix = node[:keystone][:use_virtualenv] ? ". #{venv_path}/bin/activate &&" : nil


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
  unless %w(redhat centos).include?(node.platform)
    include_recipe "apache2::mod_wsgi"
  else
    package "mod_wsgi"
  end
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
      :venv => node[:keystone][:use_virtualenv] && node[:keystone][:use_gitrepo],
      :venv_path => venv_path
    )
  end

  template "/usr/lib/cgi-bin/keystone/admin" do
    source "keystone_wsgi_bin.py.erb"
    mode 0755
    variables(
      :venv => node[:keystone][:use_virtualenv] && node[:keystone][:use_gitrepo],
      :venv_path => venv_path
    )
  end

  apache_site "000-default" do
    enable false
  end

  template "/etc/apache2/sites-available/keystone.conf" do
    path "/etc/httpd/sites-available/keystone.conf" if %w(redhat centos).include?(node.platform)
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

my_admin_host = node[:fqdn]
# For the public endpoint, we prefer the public name. If not set, then we
# use the IP address except for SSL, where we always prefer a hostname
# (for certificate validation).
my_public_host = node[:crowbar][:public_name]
if my_public_host.nil? or my_public_host.empty?
  unless node[:keystone][:api][:protocol] == "https"
    my_public_host = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "public").address
  else
    my_public_host = 'public.'+node[:fqdn]
  end
end

template "/etc/keystone/keystone.conf" do
    source "keystone.conf.erb"
    owner node[:keystone][:user]
    mode 0640
    variables(
      :sql_connection => sql_connection,
      :sql_idle_timeout => node[:keystone][:sql][:idle_timeout],
      :debug => node[:keystone][:debug],
      :verbose => node[:keystone][:verbose],
      :admin_token => node[:keystone][:service][:token],
      :bind_admin_api_host => node[:keystone][:api][:admin_host],
      :admin_api_host => my_admin_host,
      :admin_api_port => node[:keystone][:api][:admin_port], # Auth port
      :api_host => my_public_host,
      :api_port => node[:keystone][:api][:api_port], # public port
      :use_syslog => node[:keystone][:use_syslog],
      :signing_token_format => node[:keystone][:signing][:token_format],
      :signing_certfile => node[:keystone][:signing][:certfile],
      :signing_keyfile => node[:keystone][:signing][:keyfile],
      :signing_ca_certs => node[:keystone][:signing][:ca_certs],
      :protocol => node[:keystone][:api][:protocol],
      :frontend => node[:keystone][:frontend],
      :ssl_enable => (node[:keystone][:frontend] == 'native' && node[:keystone][:api][:protocol] == "https"),
      :ssl_certfile => node[:keystone][:ssl][:certfile],
      :ssl_keyfile => node[:keystone][:ssl][:keyfile],
      :ssl_cert_required => node[:keystone][:ssl][:cert_required],
      :ssl_ca_certs => node[:keystone][:ssl][:ca_certs]
    )
    if node[:keystone][:frontend]=='native'
      notifies :restart, resources(:service => "keystone"), :immediately
    elsif node[:keystone][:frontend]=='apache'
      notifies :restart, resources(:service => "apache2"), :immediately
    end
end

execute "keystone-manage db_sync" do
  command "keystone-manage db_sync"
  user node[:keystone][:user]
  group node[:keystone][:user]
  action :run
end

if node[:keystone][:signing][:token_format] == "PKI"
  if %w(redhat centos).include?(node.platform)
    directory "/etc/keystone/" do
      action :create
      owner node[:keystone][:user]
      group node[:keystone][:user]
    end
  end
  execute "keystone-manage ssl_setup" do
    user node[:keystone][:user]
    group node[:keystone][:user]
    command "keystone-manage ssl_setup --keystone-user #{node[:keystone][:user]} --keystone-group  #{node[:keystone][:user]}"
    action :run
  end
  execute "keystone-manage pki_setup" do
    user node[:keystone][:user]
    group node[:keystone][:user]
    command "keystone-manage pki_setup --keystone-user #{node[:keystone][:user]} --keystone-group  #{node[:keystone][:user]}"
    action :run
  end
end unless node.platform == "suse"

if node[:keystone][:api][:protocol] == 'https'
  if node[:keystone][:ssl][:generate_certs]
    package "openssl"
    ruby_block "generate_certs for keystone" do
      block do
        unless ::File.exists? node[:keystone][:ssl][:certfile] and ::File.exists? node[:keystone][:ssl][:keyfile]
          require "fileutils"

          Chef::Log.info("Generating SSL certificate for keystone...")

          [:certfile, :keyfile].each do |k|
            dir = File.dirname(node[:keystone][:ssl][k])
            FileUtils.mkdir_p(dir) unless File.exists?(dir)
          end

          # Generate private key
          %x(openssl genrsa -out #{node[:keystone][:ssl][:keyfile]} 4096)
          if $?.exitstatus != 0
            message = "SSL private key generation failed"
            Chef::Log.fatal(message)
            raise message
          end
          FileUtils.chown "root", node[:keystone][:group], node[:keystone][:ssl][:keyfile]
          FileUtils.chmod 0640, node[:keystone][:ssl][:keyfile]

          # Generate certificate signing requests (CSR)
          conf_dir = File.dirname node[:keystone][:ssl][:certfile]
          ssl_csr_file = "#{conf_dir}/signing_key.csr"
          ssl_subject = "\"/C=US/ST=Unset/L=Unset/O=Unset/CN=#{node[:fqdn]}\""
          %x(openssl req -new -key #{node[:keystone][:ssl][:keyfile]} -out #{ssl_csr_file} -subj #{ssl_subject})
          if $?.exitstatus != 0
            message = "SSL certificate signed requests generation failed"
            Chef::Log.fatal(message)
            raise message
          end

          # Generate self-signed certificate with above CSR
          %x(openssl x509 -req -days 3650 -in #{ssl_csr_file} -signkey #{node[:keystone][:ssl][:keyfile]} -out #{node[:keystone][:ssl][:certfile]})
          if $?.exitstatus != 0
            message = "SSL self-signed certificate generation failed"
            Chef::Log.fatal(message)
            raise message
          end

          File.delete ssl_csr_file  # Nobody should even try to use this
        end # unless files exist
      end # block
    end # ruby_block
  else # if generate_certs
    unless ::File.exists? node[:keystone][:ssl][:certfile]
      message = "Certificate \"#{node[:keystone][:ssl][:certfile]}\" is not present."
      Chef::Log.fatal(message)
      raise message
    end
    # we do not check for existence of keyfile, as the private key is allowed
    # to be in the certfile
  end # if generate_certs

  if node[:keystone][:ssl][:cert_required] and !::File.exists? node[:keystone][:ssl][:ca_certs]
    message = "Certificate CA \"#{node[:keystone][:ssl][:ca_certs]}\" is not present."
    Chef::Log.fatal(message)
    raise message
  end
end

# Silly wake-up call - this is a hack
keystone_register "wakeup keystone" do
  protocol node[:keystone][:api][:protocol]
  host my_admin_host
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
    host my_admin_host
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
    host my_admin_host
    port node[:keystone][:api][:admin_port]
    token node[:keystone][:service][:token]
    user_name user_data[0]
    user_password user_data[1]
    tenant_name user_data[2]
    action :add_user
  end
end


# Create roles
## Member is used by horizon (see OPENSTACK_KEYSTONE_DEFAULT_ROLE option)
roles = %w[admin Member]
roles.each do |role|
  keystone_register "add default #{role} role" do
    protocol node[:keystone][:api][:protocol]
    host my_admin_host
    port node[:keystone][:api][:admin_port]
    token node[:keystone][:service][:token]
    role_name role
    action :add_role
  end
end

# Create Access info
user_roles = [ 
  [node[:keystone][:admin][:username], "admin", node[:keystone][:admin][:tenant]],
  [node[:keystone][:admin][:username], "admin", node[:keystone][:default][:tenant]],
  [node[:keystone][:default][:username], "Member", node[:keystone][:default][:tenant]]
]
user_roles.each do |args|
  keystone_register "add default #{args[2]}:#{args[0]} -> #{args[1]} role" do
    protocol node[:keystone][:api][:protocol]
    host my_admin_host
    port node[:keystone][:api][:admin_port]
    token node[:keystone][:service][:token]
    user_name args[0]
    role_name args[1]
    tenant_name args[2]
    action :add_access
  end
end


# Create EC2 creds for our users
if not platform?("redhat", "centos", "fedora")
  ec2_creds = [ 
    [node[:keystone][:admin][:username], node[:keystone][:admin][:tenant]],
    [node[:keystone][:admin][:username], node[:keystone][:default][:tenant]],
    [node[:keystone][:default][:username], node[:keystone][:default][:tenant]]
  ]
  ec2_creds.each do |args|
    keystone_register "add default ec2 creds for #{args[1]}:#{args[0]}" do
      protocol node[:keystone][:api][:protocol]
      host my_admin_host
      port node[:keystone][:api][:admin_port]
      token node[:keystone][:service][:token]
      user_name args[0]
      tenant_name args[1]
      action :add_ec2
    end
  end
end

# Create keystone service
keystone_register "register keystone service" do
  protocol node[:keystone][:api][:protocol]
  host my_admin_host
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
  host my_admin_host
  port node[:keystone][:api][:admin_port]
  token node[:keystone][:service][:token]
  endpoint_service "keystone"
  endpoint_region "RegionOne"
  endpoint_publicURL "#{node[:keystone][:api][:protocol]}://#{my_public_host}:#{node[:keystone][:api][:service_port]}/v2.0"
  endpoint_adminURL "#{node[:keystone][:api][:protocol]}://#{my_admin_host}:#{node[:keystone][:api][:admin_port]}/v2.0"
  endpoint_internalURL "#{node[:keystone][:api][:protocol]}://#{my_admin_host}:#{node[:keystone][:api][:service_port]}/v2.0"
#  endpoint_global true
#  endpoint_enabled true
  action :add_endpoint_template
end

node[:keystone][:monitor] = {} if node[:keystone][:monitor].nil?
node[:keystone][:monitor][:svcs] = [] if node[:keystone][:monitor][:svcs].nil?
node[:keystone][:monitor][:svcs] << ["keystone"] if node[:keystone][:monitor][:svcs].empty?
node.save
