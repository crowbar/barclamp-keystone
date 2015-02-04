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

  if node[:keystone][:frontend] == 'native'
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

ha_enabled = node[:keystone][:ha][:enabled]

if ha_enabled
  log "HA support for keystone is enabled"
  admin_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
  bind_admin_host = admin_address
  bind_admin_port = node[:keystone][:ha][:ports][:admin_port]
  bind_service_host = admin_address
  bind_service_port = node[:keystone][:ha][:ports][:service_port]
else
  log "HA support for keystone is disabled"
  bind_admin_host = node[:keystone][:api][:admin_host]
  bind_admin_port = node[:keystone][:api][:admin_port]
  bind_service_host = node[:keystone][:api][:api_host]
  bind_service_port = node[:keystone][:api][:service_port]
end

# Ideally this would be called admin_host, but that's already being
# misleadingly used to store a value which actually represents the
# service bind address.
my_admin_host = CrowbarHelper.get_host_for_admin_url(node, ha_enabled)
my_public_host = CrowbarHelper.get_host_for_public_url(node, node[:keystone][:api][:protocol] == "https", ha_enabled)

# These are used in keystone.conf
node[:keystone][:api][:public_URL] = \
  KeystoneHelper.service_URL(node, my_public_host,
                             node[:keystone][:api][:service_port])
# This is also used for admin requests of keystoneclient
node[:keystone][:api][:admin_URL] = \
  KeystoneHelper.service_URL(node, my_admin_host,
                             node[:keystone][:api][:admin_port])

# These URLs will be registered as endpoints in keystone's database
node[:keystone][:api][:versioned_public_URL] = \
  KeystoneHelper.versioned_service_URL(node, my_public_host,
                                       node[:keystone][:api][:service_port])
node[:keystone][:api][:versioned_admin_URL] = \
  KeystoneHelper.versioned_service_URL(node, my_admin_host,
                                       node[:keystone][:api][:admin_port])
node[:keystone][:api][:versioned_internal_URL] = \
  KeystoneHelper.versioned_service_URL(node, my_admin_host,
                                       node[:keystone][:api][:service_port])

# Other barclamps need to know the hostname to reach keystone
node[:keystone][:api][:public_URL_host] = my_public_host
node[:keystone][:api][:internal_URL_host] = my_admin_host

if node[:keystone][:frontend] == 'uwsgi'

  service "keystone" do
    service_name node[:keystone][:service_name]
    supports :status => true, :restart => true
    action [ :disable, :stop ]
  end

  directory "/usr/lib/cgi-bin/keystone/" do
    owner "root"
    group "root"
    mode 0755
    action :create
    recursive true
  end

  template "/usr/lib/cgi-bin/keystone/application.py" do
    source "keystone-uwsgi.py.erb"
    mode 0755
    variables(
      :venv => node[:keystone][:use_virtualenv] && node[:keystone][:use_gitrepo],
      :venv_path => venv_path
    )
  end

  uwsgi "keystone" do
    options({
      :chdir => "/usr/lib/cgi-bin/keystone/",
      :callable => :application,
      :module => :application,
      :user => node[:keystone][:user],
      :log => "/var/log/keystone/keystone.log"
    })
    instances ([
      {:socket => "#{bind_service_host}:#{bind_service_port}", :env => "name=main"},
      {:socket => "#{bind_admin_host}:#{bind_admin_port}", :env => "name=admin"}
    ])
    service_name "keystone-uwsgi"
  end

  service "keystone-uwsgi" do
    supports :status => true, :restart => true, :start => true
    action :start
    subscribes :restart, "template[/usr/lib/cgi-bin/keystone/application.py]", :immediately
  end

elsif node[:keystone][:frontend] == 'apache'

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
    owner "root"
    group "root"
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
      :bind_admin_port => bind_admin_port, # Auth port
      :bind_admin_host => bind_admin_host,
      :bind_service_port => bind_service_port, # public port
      :bind_service_host => bind_service_host,
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

db_settings = fetch_database_settings
include_recipe "database::client"
include_recipe "#{db_settings[:backend_name]}::client"
include_recipe "#{db_settings[:backend_name]}::python-client"

crowbar_pacemaker_sync_mark "wait-keystone_database"

# Create the Keystone Database
database "create #{node[:keystone][:db][:database]} database" do
    connection db_settings[:connection]
    database_name node[:keystone][:db][:database]
    provider db_settings[:provider]
    action :create
end

database_user "create keystone database user" do
    connection db_settings[:connection]
    username node[:keystone][:db][:user]
    password node[:keystone][:db][:password]
    host '%'
    provider db_settings[:user_provider]
    action :create
end

database_user "grant database access for keystone database user" do
    connection db_settings[:connection]
    username node[:keystone][:db][:user]
    password node[:keystone][:db][:password]
    database_name node[:keystone][:db][:database]
    host '%'
    privileges db_settings[:privs]
    provider db_settings[:user_provider]
    action :grant
end

crowbar_pacemaker_sync_mark "create-keystone_database"

sql_connection = "#{db_settings[:url_scheme]}://#{node[:keystone][:db][:user]}:#{node[:keystone][:db][:password]}@#{db_settings[:address]}/#{node[:keystone][:db][:database]}"

template "/etc/keystone/keystone.conf" do
    source "keystone.conf.erb"
    owner "root"
    group node[:keystone][:group]
    mode 0640
    variables(
      :sql_connection => sql_connection,
      :sql_idle_timeout => node[:keystone][:sql][:idle_timeout],
      :debug => node[:keystone][:debug],
      :verbose => node[:keystone][:verbose],
      :admin_token => node[:keystone][:service][:token],
      :bind_admin_host => bind_admin_host,
      :bind_service_host => bind_service_host,
      :bind_admin_port => bind_admin_port,
      :bind_service_port => bind_service_port,
      :public_endpoint => node[:keystone][:api][:public_URL],
      :admin_endpoint => node[:keystone][:api][:admin_URL],
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
      :ssl_ca_certs => node[:keystone][:ssl][:ca_certs],
      :rabbit_settings => fetch_rabbitmq_settings
    )
    if node[:keystone][:frontend] == 'apache'
      notifies :restart, resources(:service => "apache2"), :immediately
    elsif node[:keystone][:frontend] == 'uwsgi'
      notifies :restart, resources(:service => "keystone-uwsgi"), :immediately
    end
end

if %w(redhat centos).include?(node.platform)
  # Permissions for /etc/keystone are wrong in the RDO repo
  directory "/etc/keystone" do
    action :create
    owner "root"
    group node[:keystone][:group]
    mode 0750
  end
end

crowbar_pacemaker_sync_mark "wait-keystone_db_sync"

execute "keystone-manage db_sync" do
  command "keystone-manage db_sync"
  user node[:keystone][:user]
  group node[:keystone][:group]
  action :run
  # We only do the sync the first time, and only if we're not doing HA or if we
  # are the founder of the HA cluster (so that it's really only done once).
  only_if { !node[:keystone][:db_synced] && (!ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node)) }
end

# We want to keep a note that we've done db_sync, so we don't do it again.
# If we were doing that outside a ruby_block, we would add the note in the
# compile phase, before the actual db_sync is done (which is wrong, since it
# could possibly not be reached in case of errors).
ruby_block "mark node for keystone db_sync" do
  block do
    node[:keystone][:db_synced] = true
    node.save
  end
  action :nothing
  subscribes :create, "execute[keystone-manage db_sync]", :immediately
end

crowbar_pacemaker_sync_mark "create-keystone_db_sync"

# Make sure the PKI bits are done on the founder first
crowbar_pacemaker_sync_mark "wait-keystone_pki" do
  fatal true
end

unless node.platform == "suse"
  if node[:keystone][:signing][:token_format] == "PKI"
    execute "keystone-manage ssl_setup" do
      user node[:keystone][:user]
      group node[:keystone][:group]
      command "keystone-manage ssl_setup --keystone-user #{node[:keystone][:user]} --keystone-group  #{node[:keystone][:group]}"
      action :run
    end
    execute "keystone-manage pki_setup" do
      user node[:keystone][:user]
      group node[:keystone][:group]
      command "keystone-manage pki_setup --keystone-user #{node[:keystone][:user]} --keystone-group  #{node[:keystone][:group]}"
      action :run
    end
  end
end

ruby_block "synchronize PKI keys for founder and remember them for non-HA case" do
  only_if { (!ha_enabled || (ha_enabled && CrowbarPacemakerHelper.is_cluster_founder?(node))) &&
            (node[:keystone][:signing][:token_format] == "PKI" || node.platform == "suse") }
  block do
    ca = File.open("/etc/keystone/ssl/certs/ca.pem", "rb") {|io| io.read} rescue ""
    signing_cert = File.open("/etc/keystone/ssl/certs/signing_cert.pem", "rb") {|io| io.read} rescue ""
    signing_key = File.open("/etc/keystone/ssl/private/signing_key.pem", "rb") {|io| io.read} rescue ""

    node[:keystone][:pki] ||= {}
    node[:keystone][:pki][:content] ||= {}

    dirty = false

    if node[:keystone][:pki][:content][:ca] != ca
      node[:keystone][:pki][:content][:ca] = ca
      dirty = true
    end
    if node[:keystone][:pki][:content][:signing_cert] != signing_cert
      node[:keystone][:pki][:content][:signing_cert] = signing_cert
      dirty = true
    end
    if node[:keystone][:pki][:content][:signing_key] != signing_key
      node[:keystone][:pki][:content][:signing_key] = signing_key
      dirty = true
    end

    node.save if dirty
  end
end

ruby_block "synchronize PKI keys for non-founder" do
  only_if { ha_enabled && !CrowbarPacemakerHelper.is_cluster_founder?(node) && (node[:keystone][:signing][:token_format] == "PKI" || node.platform == "suse") }
  block do
    ca = File.open("/etc/keystone/ssl/certs/ca.pem", "rb") {|io| io.read} rescue ""
    signing_cert = File.open("/etc/keystone/ssl/certs/signing_cert.pem", "rb") {|io| io.read} rescue ""
    signing_key = File.open("/etc/keystone/ssl/private/signing_key.pem", "rb") {|io| io.read} rescue ""

    founder = CrowbarPacemakerHelper.cluster_founder(node)

    cluster_ca = founder[:keystone][:pki][:content][:ca]
    cluster_signing_cert = founder[:keystone][:pki][:content][:signing_cert]
    cluster_signing_key = founder[:keystone][:pki][:content][:signing_key]

    # The files exist; we will keep ownership / permissions with
    # the code below
    dirty = false
    if ca != cluster_ca
      File.open("/etc/keystone/ssl/certs/ca.pem", 'w') {|f| f.write(cluster_ca) }
      dirty = true
    end
    if signing_cert != cluster_signing_cert
      File.open("/etc/keystone/ssl/certs/signing_cert.pem", 'w') {|f| f.write(cluster_signing_cert) }
      dirty = true
    end
    if signing_key != cluster_signing_key
      File.open("/etc/keystone/ssl/private/signing_key.pem", 'w') {|f| f.write(cluster_signing_key) }
      dirty = true
    end

    if dirty
      if node[:keystone][:frontend] == 'native'
        resources(:service => "keystone").run_action(:restart)
      elsif node[:keystone][:frontend] == 'apache'
        resources(:service => "apache2").run_action(:restart)
      elsif node[:keystone][:frontend] == 'uwsgi'
        resources(:service => "keystone-uwsgi").run_action(:restart)
      end
    end
  end # block
end

crowbar_pacemaker_sync_mark "create-keystone_pki"

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

if node[:keystone][:frontend] == 'native'
  # We define the service after we define all our config files, so that it's
  # started only when all files are created.
  service "keystone" do
    service_name node[:keystone][:service_name]
    supports :status => true, :start => true, :restart => true
    action [ :enable, :start ]
    subscribes :restart, resources(:template => "/etc/keystone/keystone.conf"), :immediately
    provider Chef::Provider::CrowbarPacemakerService if ha_enabled
  end
end

if ha_enabled
  include_recipe "keystone::ha"
end

crowbar_pacemaker_sync_mark "wait-keystone_register"

keystone_insecure = node["keystone"]["api"]["protocol"] == "https" && node[:keystone][:ssl][:insecure]

# Silly wake-up call - this is a hack; we use retries because the server was
# just (re)started, and might not answer on the first try
keystone_register "wakeup keystone" do
  protocol node[:keystone][:api][:protocol]
  insecure keystone_insecure
  host my_admin_host
  port node[:keystone][:api][:admin_port]
  token node[:keystone][:service][:token]
  retries 5
  retry_delay 10
  action :wakeup
end

# Create tenants
[ node[:keystone][:admin][:tenant],
  node[:keystone][:service][:tenant],
  node[:keystone][:default][:tenant]
].each do |tenant|
  keystone_register "add default #{tenant} tenant" do
    protocol node[:keystone][:api][:protocol]
    insecure keystone_insecure
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
    insecure keystone_insecure
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
    insecure keystone_insecure
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
    insecure keystone_insecure
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
ec2_creds = [
  [node[:keystone][:admin][:username], node[:keystone][:admin][:tenant]],
  [node[:keystone][:admin][:username], node[:keystone][:default][:tenant]],
  [node[:keystone][:default][:username], node[:keystone][:default][:tenant]]
]
ec2_creds.each do |args|
  keystone_register "add default ec2 creds for #{args[1]}:#{args[0]}" do
    protocol node[:keystone][:api][:protocol]
    insecure keystone_insecure
    host my_admin_host
    auth ({
        :tenant => node[:keystone][:admin][:tenant],
        :user => node[:keystone][:admin][:username],
        :password => node[:keystone][:admin][:password]
    })
    port node[:keystone][:api][:admin_port]
    user_name args[0]
    tenant_name args[1]
    action :add_ec2
  end
end

# Create keystone service
keystone_register "register keystone service" do
  protocol node[:keystone][:api][:protocol]
  insecure keystone_insecure
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
  insecure keystone_insecure
  host my_admin_host
  port node[:keystone][:api][:admin_port]
  token node[:keystone][:service][:token]
  endpoint_service "keystone"
  endpoint_region      node[:keystone][:api][:region]
  endpoint_publicURL   node[:keystone][:api][:versioned_public_URL]
  endpoint_adminURL    node[:keystone][:api][:versioned_admin_URL]
  endpoint_internalURL node[:keystone][:api][:versioned_internal_URL]
#  endpoint_global true
#  endpoint_enabled true
  action :add_endpoint_template
end

crowbar_pacemaker_sync_mark "create-keystone_register"

node[:keystone][:monitor] = {} if node[:keystone][:monitor].nil?
node[:keystone][:monitor][:svcs] = [] if node[:keystone][:monitor][:svcs].nil?
node[:keystone][:monitor][:svcs] << ["keystone"] if node[:keystone][:monitor][:svcs].empty?
node.save

# Install openstackclient so that .openrc (created below) can be used
package "python-openstackclient" do
  action :install
end

template "/root/.openrc" do
  source "openrc.erb"
  owner "root"
  group "root"
  mode 0600
  variables(
    :keystone_settings => KeystoneHelper.keystone_settings(node, @cookbook_name)
    )
end
