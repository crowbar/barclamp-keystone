
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
default[:keystone][:api][:admin_port] = "35357"
default[:keystone][:api][:admin_host] = "0.0.0.0"
default[:keystone][:api][:api_port] = "35357"
default[:keystone][:api][:api_host] = "0.0.0.0"

default[:keystone][:identity][:driver] = "keystone.identity.backends.sql.Identity"

default[:keystone][:sql][:idle_timeout] = 30

default[:keystone][:signing][:token_format] = "PKI"
default[:keystone][:signing][:certfile] = "/etc/keystone/ssl/certs/signing_cert.pem"
default[:keystone][:signing][:keyfile] = "/etc/keystone/ssl/private/signing_key.pem"
default[:keystone][:signing][:ca_certs] = "/etc/keystone/ssl/certs/ca.pem"

default[:keystone][:ssl][:insecure] = false
default[:keystone][:ssl][:certfile] = "/etc/keystone/ssl/certs/signing_cert.pem"
default[:keystone][:ssl][:keyfile] = "/etc/keystone/ssl/private/signing_key.pem"
default[:keystone][:ssl][:cert_required] = false
default[:keystone][:ssl][:ca_certs] = "/etc/keystone/ssl/certs/ca.pem"

default[:keystone][:ldap][:url] = "ldap://localhost"
default[:keystone][:ldap][:user] = "dc=Manager,dc=example,dc=com"
default[:keystone][:ldap][:password] = ""
default[:keystone][:ldap][:suffix] = "cn=example,cn=com"
default[:keystone][:ldap][:use_dumb_member] = false
default[:keystone][:ldap][:allow_subtree_delete] = false
default[:keystone][:ldap][:dumb_member] = "cn=dumb,dc=example,dc=com"
default[:keystone][:ldap][:page_size] = 0
default[:keystone][:ldap][:alias_dereferencing] = "default"
default[:keystone][:ldap][:query_scope] = "one"

default[:keystone][:ldap][:user_tree_dn] = ""
default[:keystone][:ldap][:user_filter] = ""
default[:keystone][:ldap][:user_objectclass] = 'inetOrgPerson'
default[:keystone][:ldap][:user_id_attribute] = 'cn'
default[:keystone][:ldap][:user_name_attribute] = 'sn'
default[:keystone][:ldap][:user_mail_attribute] = 'email'
default[:keystone][:ldap][:user_pass_attribute] = 'userPassword'
default[:keystone][:ldap][:user_enabled_attribute] = 'enabled'
default[:keystone][:ldap][:user_domain_id_attribute] = 'businessCategory'
default[:keystone][:ldap][:user_enabled_mask] = 0
default[:keystone][:ldap][:user_enabled_default] = 'true'
default[:keystone][:ldap][:user_attribute_ignore] = 'tenant_id,tenants'
default[:keystone][:ldap][:user_allow_create] = true
default[:keystone][:ldap][:user_allow_update] = true
default[:keystone][:ldap][:user_allow_delete] = true
default[:keystone][:ldap][:user_enabled_emulation] = false
default[:keystone][:ldap][:user_enabled_emulation_dn] = ""

default[:keystone][:ldap][:tenant_tree_dn] = ""
default[:keystone][:ldap][:tenant_filter] = ""
default[:keystone][:ldap][:tenant_objectclass] = 'groupOfNames'
default[:keystone][:ldap][:tenant_id_attribute] = 'cn'
default[:keystone][:ldap][:tenant_member_attribute] = 'member'
default[:keystone][:ldap][:tenant_name_attribute] = 'ou'
default[:keystone][:ldap][:tenant_desc_attribute] = 'description'
default[:keystone][:ldap][:tenant_enabled_attribute] = 'enabled'
default[:keystone][:ldap][:tenant_domain_id_attribute] = 'businessCategory'
default[:keystone][:ldap][:tenant_attribute_ignore] = ''
default[:keystone][:ldap][:tenant_allow_create] = true
default[:keystone][:ldap][:tenant_allow_update] = true
default[:keystone][:ldap][:tenant_allow_delete] = true
default[:keystone][:ldap][:tenant_enabled_emulation] = false
default[:keystone][:ldap][:tenant_enabled_emulation_dn] = ""

default[:keystone][:ldap][:role_tree_dn] = ""
default[:keystone][:ldap][:role_filter] = ""
default[:keystone][:ldap][:role_objectclass] = 'organizationalRole'
default[:keystone][:ldap][:role_id_attribute] = 'cn'
default[:keystone][:ldap][:role_name_attribute] = 'ou'
default[:keystone][:ldap][:role_member_attribute] = 'roleOccupant'
default[:keystone][:ldap][:role_attribute_ignore] = ''
default[:keystone][:ldap][:role_allow_create] = true
default[:keystone][:ldap][:role_allow_update] = true
default[:keystone][:ldap][:role_allow_delete] = true

default[:keystone][:ldap][:group_tree_dn] = ""
default[:keystone][:ldap][:group_filter] = ""
default[:keystone][:ldap][:group_objectclass] = 'groupOfNames'
default[:keystone][:ldap][:group_id_attribute] = 'cn'
default[:keystone][:ldap][:group_name_attribute] = 'ou'
default[:keystone][:ldap][:group_member_attribute] = 'member'
default[:keystone][:ldap][:group_desc_attribute] = 'description'
# default[:keystone][:ldap][:group_domain_id_attribute] = 'businessCategory'
default[:keystone][:ldap][:group_attribute_ignore] = ''
default[:keystone][:ldap][:group_allow_create] = true
default[:keystone][:ldap][:group_allow_update] = true
default[:keystone][:ldap][:group_allow_delete] = true

# default[:keystone][:ldap][:domain_tree_dn] = ""
# default[:keystone][:ldap][:domain_filter] = ""
# default[:keystone][:ldap][:domain_objectclass] = 'groupOfNames'
# default[:keystone][:ldap][:domain_id_attribute] = 'cn'
# default[:keystone][:ldap][:domain_name_attribute] = 'ou'
# default[:keystone][:ldap][:domain_member_attribute] = 'member'
# default[:keystone][:ldap][:domain_desc_attribute] = 'description'
# default[:keystone][:ldap][:domain_enabled_attribute] = 'enabled'
# default[:keystone][:ldap][:domain_attribute_ignore] = ''
# default[:keystone][:ldap][:domain_allow_create] = true
# default[:keystone][:ldap][:domain_allow_update] = true
# default[:keystone][:ldap][:domain_allow_delete] = true
# default[:keystone][:ldap][:domain_enabled_emulation] = false
# default[:keystone][:ldap][:domain_enabled_emulation_dn] = ""
