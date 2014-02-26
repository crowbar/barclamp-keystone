# Copyright 2014, Dell
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Attributes related to databags set during on_deployment
node.default['openstack']['db']['identity']['username'] = node['crowbar_keystone']['db']['identity']['username']
node.default['openstack']['identity']['admin_user'] = node['crowbar_keystone']['identity']['admin_user']
node.default['openstack']['secrets']['openstack_bootstrap_token'] = node['crowbar_keystone']['secrets']['bootstrap_token']

# Do not use memcache option for now
node.default['openstack']['memcached_servers'] = ''


node.default['openstack']['secret']['key_path'] = '/var/chef/data_bags/openstack_data_bag_secret'

node.override['openstack']['endpoints']['identity-bind']['host'] = '0.0.0.0'


# Database used by the OpenStack Identity (Keystone) service
database_server_addr = node["crowbar"]["database"]["server"]["v4addr"]
node.override['openstack']['db']['identity']['host'] = database_server_addr
node.override['openstack']['endpoints']['identity']['host'] = database_server_addr

