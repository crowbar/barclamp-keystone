# Copyright 2014 SUSE
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

haproxy_loadbalancer "keystone-service" do
  address node[:keystone][:api][:api_host]
  port node[:keystone][:api][:service_port]
  use_ssl (node[:keystone][:api][:protocol] == "https")
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "keystone", "keystone-server", "service_port")
  action :nothing
end.run_action(:create)

haproxy_loadbalancer "keystone-admin" do
  address node[:keystone][:api][:admin_host]
  port node[:keystone][:api][:admin_port]
  use_ssl (node[:keystone][:api][:protocol] == "https")
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "keystone", "keystone-server", "admin_port")
  action :nothing
end.run_action(:create)

# FIXME: re-enable pacemaker bits once we get clone support

## Pacemaker is only used with native frontend
#if node[:keystone][:frontend] == 'native'
#  proposal_name = node[:keystone][:config][:environment]
#  monitor_creds = node[:keystone][:admin]
#
#  service_name = proposal_name + '-service'
#  pacemaker_primitive service_name do
#    agent node[:keystone][:ha][:agent]
#    params ({
#      "os_auth_url"    => node[:keystone][:api][:versioned_admin_URL],
#      "os_tenant_name" => monitor_creds[:tenant],
#      "os_username"    => monitor_creds[:username],
#      "os_password"    => monitor_creds[:password],
#      "user"           => node[:keystone][:user]
#    })
#    op node[:keystone][:ha][:op]
#    action [:create, :start]
#  end
#
#  pacemaker_clone "clone-#{service_name}" do
#    rsc service_name
#    action :create
#  end
#end
