#
# Cookbook Name:: keystone
# Provider:: register
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

action :wakeup do
  http, headers = _build_connection(new_resource)

  # Construct the path
  path = '/v2.0/OS-KSADM/services'
  dir = 'OS-KSADM:services'

  # Lets verify that the service does not exist yet
  count = 0
  error = true
  while error and count < 50 do
    count = count + 1
    item_id, error = _find_id(http, headers, "fred", path, dir)
    sleep 1 if error
  end

  raise "Failed to validate keystone is wake" if error

  new_resource.updated_by_last_action(true)
end

action :add_service do
  http, headers = _build_connection(new_resource)

  # Construct the path
  path = '/v2.0/OS-KSADM/services'
  dir = 'OS-KSADM:services'

  # Lets verify that the service does not exist yet
  item_id, error = _find_id(http, headers, new_resource.service_name, path, dir)
  unless item_id or error
    # Service does not exist yet
    body = _build_service_object(new_resource.service_name, 
                                 new_resource.service_type,  
                                 new_resource.service_description) 
    ret = _create_item(http, headers, path, body, new_resource.service_name)
    new_resource.updated_by_last_action(ret)
  else
    raise "Failed to talk to keystone in add_service" if error
    Chef::Log.info "Service '#{new_resource.service_name}' already exists. Not creating." unless error
    new_resource.updated_by_last_action(false)
  end
end

# :add_tenant specific attributes
# attribute :tenant_name, :kind_of => String
action :add_tenant do
  http, headers = _build_connection(new_resource)

  # Construct the path
  path = '/v2.0/tenants'
  dir = 'tenants'

  # Lets verify that the service does not exist yet
  item_id, error = _find_id(http, headers, new_resource.tenant_name, path, dir)
  unless item_id or error
    # Service does not exist yet
    body = _build_tenant_object(new_resource.tenant_name) 
    ret = _create_item(http, headers, path, body, new_resource.tenant_name)
    new_resource.updated_by_last_action(ret)
  else
    raise "Failed to talk to keystone in add_tenant" if error
    Chef::Log.info "Tenant '#{new_resource.tenant_name}' already exists. Not creating." unless error
    new_resource.updated_by_last_action(false)
  end
end

# :add_user specific attributes
# attribute :user_name, :kind_of => String
# attribute :user_password, :kind_of => String
# attribute :tenant_name, :kind_of => String
action :add_user do
  http, headers = _build_connection(new_resource)

  # Lets verify that the item does not exist yet
  tenant = new_resource.tenant_name
  tenant_id, terror = _find_id(http, headers, tenant, '/v2.0/tenants', 'tenants')

  # Construct the path
  path = '/v2.0/users'
  dir = 'users'

  # Lets verify that the service does not exist yet
  item_id, uerror = _find_id(http, headers, new_resource.user_name, path, dir)

  if uerror or terror
    raise "Failed to talk to keystone in add_user"
  end

  unless item_id
    # User does not exist yet
    body = _build_user_object(new_resource.user_name, new_resource.user_password, tenant_id)
    ret = _create_item(http, headers, path, body, new_resource.user_name)
    new_resource.updated_by_last_action(ret)
  else
    path = "/v2.0/tokens"
    body = _build_auth(new_resource.user_name, new_resource.user_password, tenant_id)
    resp, data = http.send_request('POST', path, JSON.generate(body), headers)
    if resp.is_a?(Net::HTTPCreated) or resp.is_a?(Net::HTTPOK)
      Chef::Log.info "User '#{new_resource.user_name}' already exists. No password change."
      data = JSON.parse(data)
      token_id = data["access"]["token"]["id"]
      resp, data = http.delete("#{path}/#{token_id}", headers)
      if !resp.is_a?(Net::HTTPNoContent) and !resp.is_a?(Net::HTTPOK)
        Chef::Log.warn("Failed to delete temporary token")
        Chef::Log.warn("Response Code: #{resp.code}")
        Chef::Log.warn("Response Message: #{resp.message}")
      end
      new_resource.updated_by_last_action(false)
    else
      Chef::Log.info "User '#{new_resource.user_name}' already exists. Updating password."
      path = "/v2.0/users/#{item_id}/OS-KSADM/password"
      body = _build_user_password_object(item_id, new_resource.user_password)
      ret = _update_item(http, headers, path, body, new_resource.user_name)
      new_resource.updated_by_last_action(ret)
    end
  end
end

# :add_role specific attributes
# attribute :role_name, :kind_of => String
action :add_role do
  http, headers = _build_connection(new_resource)

  # Construct the path
  path = '/v2.0/OS-KSADM/roles'
  dir = 'roles'

  # Lets verify that the service does not exist yet
  item_id, error = _find_id(http, headers, new_resource.role_name, path, dir)
  unless item_id or error
    # Service does not exist yet
    body = _build_role_object(new_resource.role_name)
    ret = _create_item(http, headers, path, body, new_resource.role_name)
    new_resource.updated_by_last_action(ret)
  else
    raise "Failed to talk to keystone in add_role" if error
    Chef::Log.info "Role '#{new_resource.role_name}' already exists. Not creating." unless error
    new_resource.updated_by_last_action(false)
  end
end

# :add_access specific attributes
# attribute :tenant_name, :kind_of => String
# attribute :user_name, :kind_of => String
# attribute :role_name, :kind_of => String
action :add_access do
  http, headers = _build_connection(new_resource)

  # Lets verify that the item does not exist yet
  tenant = new_resource.tenant_name
  user = new_resource.user_name
  role = new_resource.role_name
  user_id, uerror = _find_id(http, headers, user, '/v2.0/users', 'users')
  tenant_id, terror = _find_id(http, headers, tenant, '/v2.0/tenants', 'tenants')
  role_id, rerror = _find_id(http, headers, role, '/v2.0/OS-KSADM/roles', 'roles')

  path = "/v2.0/tenants/#{tenant_id}/users/#{user_id}/roles"
  t_role_id, aerror = _find_id(http, headers, role, path, 'roles')

  error = (aerror or rerror or uerror or terror)
  unless role_id == t_role_id or error
    # Service does not exist yet
    ret = _update_item(http, headers, "#{path}/OS-KSADM/#{role_id}", nil, new_resource.role_name)
    new_resource.updated_by_last_action(ret)
  else
    raise "Failed to talk to keystone in add_access" if error
    Chef::Log.info "Access '#{tenant}:#{user} -> #{role}}' already exists. Not creating." unless error
    new_resource.updated_by_last_action(false)
  end
end

# :add_ec2 specific attributes
# attribute :user_name, :kind_of => String
# attribute :tenant_name, :kind_of => String
action :add_ec2 do
  http, headers = _build_connection(new_resource)

  # Lets verify that the item does not exist yet
  tenant = new_resource.tenant_name
  user = new_resource.user_name
  user_id, uerror = _find_id(http, headers, user, '/v2.0/users', 'users')
  tenant_id, terror = _find_id(http, headers, tenant, '/v2.0/tenants', 'tenants')

  path = "/v2.0/users/#{user_id}/credentials/OS-EC2"
  t_tenant_id, aerror = _find_id(http, headers, tenant_id, path, 'credentials', 'tenant_id', 'tenant_id')
  
  error = (aerror or uerror or terror)
  unless tenant_id == t_tenant_id or error
    # Service does not exist yet
    body = _build_ec2_object(tenant_id)
    ret = _create_item(http, headers, path, body, tenant)
    new_resource.updated_by_last_action(ret)
  else
    raise "Failed to talk to keystone in add_ec2_creds" if error
    Chef::Log.info "EC2 '#{tenant}:#{user}' already exists. Not creating." unless error
    new_resource.updated_by_last_action(false)
  end
end

action :add_endpoint_template do
  http, headers = _build_connection(new_resource)

  # Look up my service id
  # Construct the path
  path = '/v2.0/OS-KSADM/services'
  dir = 'OS-KSADM:services'
  my_service_id, error = _find_id(http, headers, new_resource.endpoint_service, path, dir)
  unless my_service_id
      Chef::Log.error "Couldn't find service #{new_resource.endpoint_service} in keystone"
      raise "Failed to talk to keystone in add_endpoint_template" if error
      new_resource.updated_by_last_action(false)
  end

  # Construct the path
  path = '/v2.0/endpoints'

  # Lets verify that the endpoint does not exist yet
  resp, data = http.request_get(path, headers) 
  if resp.is_a?(Net::HTTPOK)
      matched_endpoint = false
      replace_old = false
      old_endpoint_id = ""
      data = JSON.parse(data)
      data["endpoints"].each do |endpoint|
          if endpoint["service_id"].to_s == my_service_id.to_s
              if endpoint_needs_update endpoint, new_resource
                  replace_old = true
                  old_endpoint_id = endpoint["id"]
                  break
              else
                  matched_endpoint = true
                  break
              end
          end
      end
      if matched_endpoint
          Chef::Log.info("Already existing keystone endpointTemplate for '#{new_resource.endpoint_service}' - not creating")
          new_resource.updated_by_last_action(false)
      else
          # Delete the old existing endpoint first if required
          if replace_old
              Chef::Log.info("Deleting old endpoint #{old_endpoint_id}")
              resp, data = http.delete("#{path}/#{old_endpoint_id}", headers)
              if !resp.is_a?(Net::HTTPNoContent) and !resp.is_a?(Net::HTTPOK)
                  Chef::Log.warn("Failed to delete old endpoint")
                  Chef::Log.warn("Response Code: #{resp.code}")
                  Chef::Log.warn("Response Message: #{resp.message}")
              end
          end
          # endpointTemplate does not exist yet
          body = _build_endpoint_template_object(
                 my_service_id,
                 new_resource.endpoint_region, 
                 new_resource.endpoint_adminURL, 
                 new_resource.endpoint_internalURL, 
                 new_resource.endpoint_publicURL, 
                 new_resource.endpoint_global, 
                 new_resource.endpoint_enabled)
          resp, data = http.send_request('POST', path, JSON.generate(body), headers)
          if resp.is_a?(Net::HTTPCreated)
              Chef::Log.info("Created keystone endpointTemplate for '#{new_resource.endpoint_service}'")
              new_resource.updated_by_last_action(true)
          elsif resp.is_a?(Net::HTTPOK)
              Chef::Log.info("Updated keystone endpointTemplate for '#{new_resource.endpoint_service}'")
              new_resource.updated_by_last_action(true)
          else
              Chef::Log.error("Unable to create endpointTemplate for '#{new_resource.endpoint_service}'")
              Chef::Log.error("Response Code: #{resp.code}")
              Chef::Log.error("Response Message: #{resp.message}")
              raise "Failed to talk to keystone in add_endpoint_template (2)" if error
              new_resource.updated_by_last_action(false)
          end
      end
  else
      Chef::Log.error "Unknown response from Keystone Server"
      Chef::Log.error("Response Code: #{resp.code}")
      Chef::Log.error("Response Message: #{resp.message}")
      new_resource.updated_by_last_action(false)
      raise "Failed to talk to keystone in add_endpoint_template (3)" if error
  end
end


# Return true on success
private
def _create_item(http, headers, path, body, name)
  resp, data = http.send_request('POST', path, JSON.generate(body), headers)
  if resp.is_a?(Net::HTTPCreated)
    Chef::Log.info("Created keystone item '#{name}'")
    return true
  elsif resp.is_a?(Net::HTTPOK)
    Chef::Log.info("Updated keystone item '#{name}'")
    return true
  else
    Chef::Log.error("Unable to create item '#{name}'")
    Chef::Log.error("Response Code: #{resp.code}")
    Chef::Log.error("Response Message: #{resp.message}")
    raise "Failed to talk to keystone in _create_item"
  end
end

# Return true on success
private
def _update_item(http, headers, path, body, name)
  unless body.nil?
    resp, data = http.send_request('PUT', path, JSON.generate(body), headers)
  else
    resp, data = http.send_request('PUT', path, nil, headers)
  end
  if resp.is_a?(Net::HTTPOK)
    Chef::Log.info("Updated keystone item '#{name}'")
    return true
  elsif resp.is_a?(Net::HTTPCreated)
    Chef::Log.info("Created keystone item '#{name}'")
    return true
  else
    Chef::Log.error("Unable to updated item '#{name}'")
    Chef::Log.error("Response Code: #{resp.code}")
    Chef::Log.error("Response Message: #{resp.message}")
    raise "Failed to talk to keystone in _update_item"
  end
end

private
def _build_connection(new_resource)
  # Need to require net/https so that Net::HTTP gets monkey-patched
  # to actually support SSL:
  require 'net/https' if new_resource.protocol == "https"

  # Construct the http object
  http = Net::HTTP.new(new_resource.host, new_resource.port)
  http.use_ssl = true if new_resource.protocol == "https"

  # Fill out the headers
  headers = _build_headers(new_resource.token)

  [ http, headers ]
end

private
def _find_id(http, headers, svc_name, spath, dir, key = 'name', ret = 'id')
  # Construct the path
  my_service_id = nil
  error = false
  resp, data = http.request_get(spath, headers) 
  if resp.is_a?(Net::HTTPOK)
    data = JSON.parse(data)
    data = data[dir]

    data.each do |svc|
      my_service_id = svc[ret] if svc[key] == svc_name
      break if my_service_id
    end 
  else
    Chef::Log.error "Find #{spath}: #{svc_name}: Unknown response from Keystone Server"
    Chef::Log.error("Response Code: #{resp.code}")
    Chef::Log.error("Response Message: #{resp.message}")
    error = true
  end
  [ my_service_id, error ]
end

private
def _build_service_object(svc_name, svc_type, svc_desc)
  svc_obj = Hash.new
  svc_obj.store("name", svc_name)
  svc_obj.store("type", svc_type)
  svc_obj.store("description", svc_desc)
  ret = Hash.new
  ret.store("OS-KSADM:service", svc_obj)
  return ret
end

private
def _build_user_object(user_name, password, tenant_id)
  svc_obj = Hash.new
  svc_obj.store("name", user_name)
  svc_obj.store("password", password)
  svc_obj.store("tenant_id", tenant_id)
  svc_obj.store("enabled", true)
  ret = Hash.new
  ret.store("user", svc_obj)
  return ret
end

private
def _build_auth(user_name, password, tenant_id)
  password_obj = Hash.new
  password_obj.store("username", user_name)
  password_obj.store("password", password)
  auth_obj = Hash.new
  auth_obj.store("tenantId", tenant_id)
  auth_obj.store("passwordCredentials", password_obj)
  ret = Hash.new
  ret.store("auth", auth_obj)
  return ret
end

private
def _build_user_password_object(user_id, password)
  user_obj = Hash.new
  user_obj.store("id", user_id)
  user_obj.store("password", password)
  ret = Hash.new
  ret.store("user", user_obj)
  return ret
end

private
def _build_role_object(role_name)
  svc_obj = Hash.new
  svc_obj.store("name", role_name)
  ret = Hash.new
  ret.store("role", svc_obj)
  return ret
end

private
def _build_tenant_object(tenant_name)
  svc_obj = Hash.new
  svc_obj.store("name", tenant_name)
  svc_obj.store("enabled", true)
  ret = Hash.new
  ret.store("tenant", svc_obj)
  return ret
end

private
def _build_access_object(role_id, role_name)
  svc_obj = Hash.new
  svc_obj.store("name", role_name)
  svc_obj.store("id", role_id)
  ret = Hash.new
  ret.store("role", svc_obj)
  return ret
end

private
def _build_ec2_object(tenant_id)
  ret = Hash.new
  ret.store("tenant_id", tenant_id)
  return ret
end

private
def _build_endpoint_template_object(service, region, adminURL, internalURL, publicURL, global=true, enabled=true)
  template_obj = Hash.new
  template_obj.store("service_id", service)
  template_obj.store("region", region)
  template_obj.store("adminurl", adminURL)
  template_obj.store("internalurl", internalURL)
  template_obj.store("publicurl", publicURL)
  if global
    template_obj.store("global", "True")
  else
    template_obj.store("global", "False")
  end
  if enabled
    template_obj.store("enabled", true)
  else
    template_obj.store("enabled", false)
  end
  ret = Hash.new
  ret.store("endpoint", template_obj)
  return ret
end

private
def _build_headers(token)
  ret = Hash.new
  ret.store('X-Auth-Token', token)
  ret.store('Content-type', 'application/json')
  return ret
end

def endpoint_needs_update(endpoint, new_resource)
  if endpoint["publicurl"] == new_resource.endpoint_publicURL and
        endpoint["adminurl"] == new_resource.endpoint_adminURL and
        endpoint["internalurl"] == new_resource.endpoint_internalURL
    return false
  else
    return true
  end
end
