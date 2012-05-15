#
# Cookbook Name:: mysql
# Resource:: database
#
# Copyright:: 2008-2011, Opscode, Inc <legal@opscode.com>
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

actions :add_service, :add_endpoint_template, :add_tenant, :add_user, :add_role, :add_access, :add_ec2, :wakeup

attribute :host, :kind_of => String
attribute :port, :kind_of => Integer
attribute :token, :kind_of => String

# :add_service specific attributes
attribute :service_name, :kind_of => String
attribute :service_type, :kind_of => String
attribute :service_description, :kind_of => String

# :add_endpoint_template specific attributes
attribute :endpoint_service, :kind_of => String
attribute :endpoint_region, :kind_of => String
attribute :endpoint_adminURL, :kind_of => String
attribute :endpoint_internalURL, :kind_of => String
attribute :endpoint_publicURL, :kind_of => String
attribute :endpoint_global, :default => true
attribute :endpoint_enabled, :default => true

# :add_tenant specific attributes
attribute :tenant_name, :kind_of => String

# :add_user specific attributes
attribute :user_name, :kind_of => String
attribute :user_password, :kind_of => String

# :add_role specific attributes
attribute :role_name, :kind_of => String

# :add_access specific attributes
attribute :user_name, :kind_of => String
attribute :role_name, :kind_of => String
attribute :tenant_name, :kind_of => String

# :add_ec2 specific attributes
attribute :user_name, :kind_of => String
attribute :tenant_name, :kind_of => String

