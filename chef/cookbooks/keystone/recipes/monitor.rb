#
# Copyright 2011, Dell
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
# Author: andi abes
#

####
# if monitored by nagios, install the nrpe commands

# Node addresses are dynamic and can't be set from attributes only.
my_ipaddress = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address

node[:keystone][:monitor] = {} if node[:keystone][:monitor].nil?
node[:keystone][:monitor][:svcs] = [] if node[:keystone][:monitor][:svcs].nil?
node[:keystone][:monitor][:ports] = {} if node[:keystone][:monitor][:ports].nil?
node[:keystone][:monitor][:ports]["keystone-service"] = [my_ipaddress, node[:keystone][:api][:service_port]]
node[:keystone][:monitor][:ports]["keystone-admin"] = [my_ipaddress, node[:keystone][:api][:admin_port]]

svcs = node[:keystone][:monitor][:svcs]
ports = node[:keystone][:monitor][:ports]
log ("will monitor keystone svcs: #{svcs.join(',')} and ports #{ports.values.join(',')}")

include_recipe "nagios::common" if node["roles"].include?("nagios-client")

template "/etc/nagios/nrpe.d/keystone_nrpe.cfg" do
  source "keystone_nrpe.cfg.erb"
  mode "0644"
  group node[:nagios][:group]
  owner node[:nagios][:user]
  variables( {
    :svcs => svcs ,
    :ports => ports
  })
   notifies :restart, "service[nagios-nrpe-server]"
end if node["roles"].include?("nagios-client")

