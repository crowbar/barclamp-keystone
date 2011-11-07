
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

default[:openstack][:keystone][:debug]=true
default[:openstack][:keystone][:user]="keystone"
default[:openstack][:keystone][:uid]="505"
default[:openstack][:keystone][:group]="nogroup"
default[:openstack][:keystone][:seed_data]=true

default[:keystone][:db][:database] = "keystone"
default[:keystone][:db][:user] = "keystone"
default[:keystone][:db][:password] = "" # Set by Recipe





