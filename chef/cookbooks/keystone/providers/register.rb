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
  path = '/v3/services'
  dir = 'services'

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
  path = '/v3/services'
  dir = 'services'

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

action :add_project do
  add_project(new_resource.project_name)
end

# :add_tenant specific attributes
# attribute :tenant_name, :kind_of => String
action :add_tenant do
  Chef::Log.warn "keystone_register action ':add_tenant' is deprecated please use ':add_project'"
  add_project(new_resource.tenant_name)
end

# :add_user specific attributes
# attribute :user_name, :kind_of => String
# attribute :user_password, :kind_of => String
# attribute :tenant_name, :kind_of => String
action :add_user do
  http, headers = _build_connection(new_resource)

  # Lets verify that the item does not exist yet
  tenant = new_resource.tenant_name
  tenant_id, terror = _find_id(http, headers, tenant, '/v3/projects', 'projects')

  # Construct the path
  path = '/v3/users'
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
    path = "/v3/auth/tokens"
    body = _build_auth(new_resource.user_name, new_resource.user_password)
    resp = http.send_request('POST', path, JSON.generate(body), headers)
    if resp.is_a?(Net::HTTPCreated) or resp.is_a?(Net::HTTPOK)
      Chef::Log.info "User '#{new_resource.user_name}' already exists. No password change."
      new_resource.updated_by_last_action(false)
      token_id = resp.get_fields("X-Subject-Token").first
      headers.store("X-Subject-Token", token_id)
      resp = http.delete("#{path}", headers)
      if !resp.is_a?(Net::HTTPNoContent) and !resp.is_a?(Net::HTTPOK)
        Chef::Log.warn("Failed to delete temporary token")
        Chef::Log.warn("Response Code: #{resp.code}")
        Chef::Log.warn("Response Message: #{resp.message}")
      end
    else
      Chef::Log.info "User '#{new_resource.user_name}' already exists. Updating password."
      path = "/v3/users/#{item_id}"
      body = _build_user_password_object(item_id, new_resource.user_password)
      ret = _update_item(http, headers, path, body, new_resource.user_name, true)
      new_resource.updated_by_last_action(ret)
    end
  end
end

# :add_role specific attributes
# attribute :role_name, :kind_of => String
action :add_role do
  http, headers = _build_connection(new_resource)

  # Construct the path
  path = '/v3/roles'
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
  user_id, uerror = _find_id(http, headers, user, '/v3/users', 'users')
  tenant_id, terror = _find_id(http, headers, tenant, '/v3/projects', 'projects')
  role_id, rerror = _find_id(http, headers, role, '/v3/roles', 'roles')

  path = "/v3/projects/#{tenant_id}/users/#{user_id}/roles"
  t_role_id, aerror = _find_id(http, headers, role, path, 'roles')

  error = (aerror or rerror or uerror or terror)
  unless role_id == t_role_id or error
    # Service does not exist yet
    ret = _update_item(http, headers, "#{path}/#{role_id}", nil, new_resource.role_name)
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

  headers.delete('X-Auth-Token')
  body = _build_auth(new_resource.auth[:user], new_resource.auth[:password])
  resp = http.send_request('POST', '/v3/auth/tokens', JSON.generate(body),headers)
  headers.store('X-Auth-Token', resp.get_fields("X-Subject-Token").first)

  # Lets verify that the item does not exist yet
  tenant = new_resource.tenant_name
  user = new_resource.user_name
  user_id, uerror = _find_id(http, headers, user, '/v3/users', 'users')
  tenant_id, terror = _find_id(http, headers, tenant, '/v3/projects', 'projects')

  path = "/v3/users/#{user_id}/credentials/OS-EC2"
  # Note: tenant_id is correct here even when using the V3 API
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
  path = '/v3/services'
  dir = 'services'
  my_service_id, error = _find_id(http, headers, new_resource.endpoint_service, path, dir)
  unless my_service_id
    Chef::Log.error "Couldn't find service #{new_resource.endpoint_service} in keystone"
    raise "Failed to talk to keystone in add_endpoint_template" if error
    new_resource.updated_by_last_action(false)
  end

  # Construct the path
  path = '/v3/endpoints'

  ["public", "admin", "internal"].each do |interface|
    endpoint_url = new_resource.endpoint_internalURL
    if interface == "public"
      endpoint_url = new_resource.endpoint_publicURL
    elsif interface == "admin"
      endpoint_url = new_resource.endpoint_adminURL
    end

    new_resource.updated_by_last_action(false)

    # Lets verify that the endpoint does not exist yet
    resp = http.request_get("#{path}?interface=#{interface}&service_id=#{my_service_id}", headers)
    if resp.is_a?(Net::HTTPOK)
      matched_endpoint = false
      replace_old = false
      old_endpoint_id = ""
      Chef::Log.info("Reply: #{resp.read_body}")
      data = JSON.parse(resp.read_body)
      data["endpoints"].each do |endpoint|
        if endpoint_needs_update(endpoint, new_resource, endpoint_url)
          replace_old = true
          old_endpoint_id = endpoint["id"]
          break
        else
          matched_endpoint = true
          break
        end
      end
      if matched_endpoint
        Chef::Log.info("'#{interface}' endpoint for '#{new_resource.endpoint_service}' already existing - not creating")
      else
        # Delete the old existing endpoint first if required
        if replace_old
          Chef::Log.info("Deleting old endpoint #{old_endpoint_id}")
          resp = http.delete("#{path}/#{old_endpoint_id}", headers)
          if !resp.is_a?(Net::HTTPNoContent) and !resp.is_a?(Net::HTTPOK)
            Chef::Log.warn("Failed to delete old endpoint")
            Chef::Log.warn("Response Code: #{resp.code}")
            Chef::Log.warn("Response Message: #{resp.message}")
          end
        end
        # endpointTemplate does not exist yet
        body = _build_endpoint_template_object(my_service_id,
                                               new_resource.endpoint_region,
                                               endpoint_url,
                                               interface)
        resp = http.send_request('POST', path, JSON.generate(body), headers)
        if resp.is_a?(Net::HTTPCreated)
          Chef::Log.info("Created '#{interface}' endpoint for '#{new_resource.endpoint_service}'")
          new_resource.updated_by_last_action(true)
        elsif resp.is_a?(Net::HTTPOK)
          Chef::Log.info("Updated '#{interface}' endpoint for '#{new_resource.endpoint_service}'")
          new_resource.updated_by_last_action(true)
        else
          Chef::Log.error("Unable to create '#{interface}' endpoint for '#{new_resource.endpoint_service}'")
          Chef::Log.error("Response Code: #{resp.code}")
          Chef::Log.error("Response Message: #{resp.message}")
          raise "Failed to talk to keystone in add_endpoint_template (2)" if error
        end
      end
    else
      Chef::Log.error "Unknown response from Keystone Server"
      Chef::Log.error("Response Code: #{resp.code}")
      Chef::Log.error("Response Message: #{resp.message}")
      raise "Failed to talk to keystone in add_endpoint_template (3)" if error
    end
  end
end

private
def add_project(project_name)
  http, headers = _build_connection(new_resource)

  # Construct the path
  path = '/v3/projects'
  dir = 'projects'

  # Lets verify that the service does not exist yet
  item_id, error = _find_id(http, headers, project_name, path, dir)
  unless item_id or error
    # Service does not exist yet
    body = _build_project_object(project_name)
    ret = _create_item(http, headers, path, body, project_name)
    new_resource.updated_by_last_action(ret)
  else
    raise "Failed to talk to keystone in add_project" if error
    Chef::Log.info "Project '#{project_name}' already exists. Not creating." unless error
    new_resource.updated_by_last_action(false)
  end
end

# Return true on success
private
def _create_item(http, headers, path, body, name)
  resp = http.send_request('POST', path, JSON.generate(body), headers)
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
def _update_item(http, headers, path, body, name, use_patch=false)
  req = use_patch ? 'PATCH' : 'PUT'
  unless body.nil?
    resp = http.send_request(req, path, JSON.generate(body), headers)
  else
    resp = http.send_request(req, path, nil, headers)
  end
  if resp.is_a?(Net::HTTPOK)
    Chef::Log.info("Updated keystone item '#{name}'")
    return true
  elsif resp.is_a?(Net::HTTPCreated) or resp.is_a?(Net::HTTPNoContent)
    Chef::Log.info("Created keystone item '#{name}'")
    return true
  else
    Chef::Log.error("Unable to update item '#{name}'")
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
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE if new_resource.insecure

  # Fill out the headers
  headers = _build_headers(new_resource.token)

  [ http, headers ]
end

private
def _find_id(http, headers, svc_name, spath, dir, key = 'name', ret = 'id')
  # Construct the path
  my_service_id = nil
  error = false
  resp = http.request_get(spath, headers)
  if resp.is_a?(Net::HTTPOK)
    data = JSON.parse(resp.read_body)
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
  ret.store("service", svc_obj)
  return ret
end

private
def _build_user_object(user_name, password, tenant_id)
  svc_obj = Hash.new
  svc_obj.store("name", user_name)
  svc_obj.store("password", password)
  svc_obj.store("default_project_id", tenant_id)
  svc_obj.store("domain_id", "default")
  svc_obj.store("email", nil)
  svc_obj.store("enabled", true)
  ret = Hash.new
  ret.store("user", svc_obj)
  return ret
end

private
def _build_auth(user_name, password)
  domain_obj = Hash.new
  domain_obj.store("id", "default")
  user_obj = Hash.new
  user_obj.store("name", user_name)
  user_obj.store("password", password)
  user_obj.store("domain", domain_obj)
  password_obj = Hash.new
  password_obj.store("user", user_obj)
  identity_obj = Hash.new
  identity_obj.store("methods", ["password"])
  identity_obj.store("password", password_obj)
  auth_obj = Hash.new
  auth_obj.store("identity", identity_obj)
  ret = Hash.new
  ret.store("auth", auth_obj)
  return ret
end

private
def _build_user_password_object(user_id, password)
  user_obj = Hash.new
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
def _build_project_object(project_name)
  svc_obj = Hash.new
  svc_obj.store("name", project_name)
  svc_obj.store("domain_id", "default")
  svc_obj.store("enabled", true)
  ret = Hash.new
  ret.store("project", svc_obj)
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
  # Note: tenant_id is correct here even when using the V3 API
  ret.store("tenant_id", tenant_id)
  return ret
end

private
def _build_endpoint_template_object(service, region, endpoint_url, interface)
  template_obj = Hash.new
  template_obj.store("service_id", service)
  template_obj.store("region", region)
  template_obj.store("url", endpoint_url)
  template_obj.store("interface", interface)

  ret = Hash.new
  ret.store("endpoint", template_obj)
  return ret
end

private
def _build_headers(token = nil)
  ret = Hash.new
  ret.store('X-Auth-Token', token) if token
  ret.store('Content-type', 'application/json')
  return ret
end

def endpoint_needs_update(endpoint, new_resource, endpoint_url)
  if endpoint["url"] == endpoint_url and endpoint["region"] == new_resource.endpoint_region
    return false
  else
    return true
  end
end
