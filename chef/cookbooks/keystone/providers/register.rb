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

action :add_service do
  http, header = _build_connection(new_resource)

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
    ret = _create_item(http, headers, path, JSON.generate(body), new_resource.service_name)
    new_resource.updated_by_last_action(ret)
  else
    Chef::Log.info "Service '#{new_resource.service_name}' already exists.. Not creating." if error
    new_resource.updated_by_last_action(false)
  end
end

# :add_tenant specific attributes
# attribute :tenant_name, :kind_of => String
action :add_tenant do
  http, header = _build_connection(new_resource)

  # Construct the path
  path = '/v2.0/tenants'
  dir = 'tenants'

  # Lets verify that the service does not exist yet
  item_id, error = _find_id(http, headers, new_resource.service_name, path, dir)
  unless item_id or error
    # Service does not exist yet
    body = _build_tenant_object(new_resource.tenant_name) 
    ret = _create_item(http, headers, path, JSON.generate(body), new_resource.tenant_name)
    new_resource.updated_by_last_action(ret)
  else
    Chef::Log.info "Tenant '#{new_resource.tenant_name}' already exists.. Not creating." if error
    new_resource.updated_by_last_action(false)
  end
end

# :add_user specific attributes
# attribute :user_name, :kind_of => String
# attribute :user_password, :kind_of => String
action :add_user do
  http, header = _build_connection(new_resource)

  # Construct the path
  path = '/v2.0/users'
  dir = 'users'

  # Lets verify that the service does not exist yet
  item_id, error = _find_id(http, headers, new_resource.service_name, path, dir)
  unless item_id or error
    # Service does not exist yet
    body = _build_user_object(new_resource.user_name, new_resource.user_password) 
    ret = _create_item(http, headers, path, JSON.generate(body), new_resource.user_name)
    new_resource.updated_by_last_action(ret)
  else
    Chef::Log.info "User '#{new_resource.user_name}' already exists.. Not creating." if error
    new_resource.updated_by_last_action(false)
  end
end

# :add_role specific attributes
# attribute :role_name, :kind_of => String
action :add_role do
  http, header = _build_connection(new_resource)

  # Construct the path
  path = '/v2.0/roles'
  dir = 'roles'

  # Lets verify that the service does not exist yet
  item_id, error = _find_id(http, headers, new_resource.role_name, path, dir)
  unless item_id or error
    # Service does not exist yet
    body = _build_user_object(new_resource.role_name)
    ret = _create_item(http, headers, path, JSON.generate(body), new_resource.role_name)
    new_resource.updated_by_last_action(ret)
  else
    Chef::Log.info "User '#{new_resource.role_name}' already exists.. Not creating." if error
    new_resource.updated_by_last_action(false)
  end
end

# :add_access specific attributes
# attribute :tenant_name, :kind_of => String
# attribute :user_name, :kind_of => String
# attribute :role_name, :kind_of => String
action :add_access do
  http, header = _build_connection(new_resource)

  # Lets verify that the item does not exist yet
  tenant = new_resource.tenant_name
  user = new_resource.user_name
  role = new_resource.role_name
  user_id, uerror = _find_id(http, headers, user, '/v2.0/users', 'users')
  tenant_id, terror = _find_id(http, headers, tenant, '/v2.0/tenants', 'tenants')
  role_id, rerror = _find_id(http, headers, role, '/v2.0/roles', 'roles')

  path = "/v2.0/tenants/#{tenant_id}/users/#{user_id}/roles"
  t_role_id, aerror = _find_id(http, headers, role, path, 'roles')
  
  unless role_id == t_role_id or (aerror or rerror or uerror or terror)
    # Service does not exist yet
    body = _build_access_object(new_resource.role_name)
    ret = _create_item(http, headers, path, JSON.generate(body), new_resource.role_name)
    new_resource.updated_by_last_action(ret)
  else
    Chef::Log.info "Access '#{tenant}:#{user} -> #{role}}' already exists.. Not creating." if error
    new_resource.updated_by_last_action(false)
  end
end

# :add_ec2 specific attributes
# attribute :user_name, :kind_of => String
# attribute :tenant_name, :kind_of => String
action :add_ec2 do
# GREG: To do
end

action :add_endpoint_template do
  http, header = _build_connection(new_resource)

  # Construct the path
  path = '/v2.0/endpoints'

  # Look up my service id
  my_service_id, error = find_service_id(http, headers, new_resource.endpoint_service)
  unless my_service_id
      Chef::Log.error "Couldn't find service #{new_resource.endpoint_service} in keystone"
      new_resource.updated_by_last_action(false)
      # XXX: Should really exit fail here.
      return
  end

  # Lets verify that the endpoint does not exist yet
  resp, data = http.request_get(path, headers) 
  if resp.is_a?(Net::HTTPOK)
      matched_service = false
      data = JSON.parse(data)
      data["endpoints"].each do |endpoint|
          if endpoint["service_id"].to_i === my_service_id.to_i
              matched_service = true
              break
          end
      end
      if matched_service
          Chef::Log.info("Already existing keystone endpointTemplate for '#{new_resource.endpoint_service}' - not creating")
          new_resource.updated_by_last_action(false)
      else
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
          else
              Chef::Log.error("Unable to create endpointTemplate for '#{new_resource.endpoint_service}'")
              Chef::Log.error("Response Code: #{resp.code}")
              Chef::Log.error("Response Message: #{resp.message}")
              new_resource.updated_by_last_action(false)
              # XXX: Should really exit fail here.
          end
      end
  else
      Chef::Log.error "Unknown response from Keystone Server"
      Chef::Log.error("Response Code: #{resp.code}")
      Chef::Log.error("Response Message: #{resp.message}")
      new_resource.updated_by_last_action(false)
      # XXX: Should really exit fail here.
  end
end


private
def _create_item(http, headers, path, body, name)
  resp, data = http.send_request('POST', path, JSON.generate(body), headers)
  if resp.is_a?(Net::HTTPCreated)
    Chef::Log.info("Created keystone service '#{name}'")
    return true
  else
    Chef::Log.error("Unable to create service '#{name}'")
    Chef::Log.error("Response Code: #{resp.code}")
    Chef::Log.error("Response Message: #{resp.message}")
    return false
    # XXX: Should really exit fail here.
  end
end

private
def _build_connection(new_resource)
  # Construct the http object
  http = Net::HTTP.new(new_resource.host, new_resource.port)

  # Fill out the headers
  headers = _build_headers(new_resource.token)

  [ http, headers ]
end

private
def _find_id(http, headers, svc_name, spath, dir)
  # Construct the path
  my_service_id = nil
  error = false
  resp, data = http.request_get(spath, headers) 
  if resp.is_a?(Net::HTTPOK)
    data = JSON.parse(data)
    data = data[dir]

    data.each do |svc|
      my_service_id = svc["id"] if svc["name"] == svc_name
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
def _build_user_object(user_name, password)
  svc_obj = Hash.new
  svc_obj.store("name", user_name)
  svc_obj.store("password", password)
  svc_obj.store("enabled", "true")
  ret = Hash.new
  ret.store("user", svc_obj)
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
def _build_tenant_object(role_name)
  svc_obj = Hash.new
  svc_obj.store("name", role_name)
  svc_obj.store("enabled", "true")
  ret = Hash.new
  ret.store("tenant", svc_obj)
  return ret
end

private
def _build_access_object(role_name)
  # GREG: Fix this.
  svc_obj = Hash.new
  svc_obj.store("name", role_name)
  svc_obj.store("enabled", "true")
  ret = Hash.new
  ret.store("tenant", svc_obj)
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
    template_obj.store("global", 1)
  else
    template_obj.store("global", 0)
  end
  if enabled
    template_obj.store("enabled", 1)
  else
    template_obj.store("enabled", 0)
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
