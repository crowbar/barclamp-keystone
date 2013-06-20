
# Copyright (c) 2011 Dell Inc.
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

unless platform == "suse"
  default[:keystone][:user] = "keystone"
  default[:keystone][:service_name] = "keystone"
else
  default[:keystone][:user] = "openstack-keystone"
  default[:keystone][:service_name] = "openstack-keystone"
end

default[:keystone][:debug] = false
default[:keystone][:frontend] = 'apache'
default[:keystone][:verbose] = false

default[:keystone][:db][:database] = "keystone"
default[:keystone][:db][:user] = "keystone"
default[:keystone][:db][:password] = "" # Set by Recipe

default[:keystone][:api][:protocol] = "http"
default[:keystone][:api][:service_port] = "5000"
default[:keystone][:api][:service_host] = "0.0.0.0"
default[:keystone][:api][:admin_port] = "35357"
default[:keystone][:api][:admin_host] = "0.0.0.0"
default[:keystone][:api][:api_port] = "35357"
default[:keystone][:api][:api_host] = "0.0.0.0"


default[:keystone][:sql][:idle_timeout] = 30
default[:keystone][:sql][:min_pool_size] = 5
default[:keystone][:sql][:max_pool_size] = 10
default[:keystone][:sql][:pool_timeout] = 200
