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
  # Construct the http object
  http = Net::HTTP.new(new_resource.host, 5001)

  # Fill out the headers
  headers = {
    'X-Auth-Token' => new_resource.token,
    'Content-Type' => 'application/json'
  } 

  # Construct the path
  path = '/v2.0/services/'

  # Lets verify that the service does not exist yet

  Chef::Log.error("PATH: [" + path + new_resource.service_name + "]")
  Chef::Log.error("DESC: [" + new_resource.service_description + "]")
  Chef::Log.error("HOST: [" + new_resource.host + "]")
  Chef::Log.error("PORT: [5001]")
  Chef::Log.error("TOKEN: [" + new_resource.token + "]")


  resp, data = http.request_get(path + new_resource.service_name, headers)
  if resp.is_a?(Net::HTTPNotFound)
    # Service does not exist yet
    body = _build_service_object(new_resource.service_name, new_resource.service_description) 
    resp, data = http.send_request('POST', path, JSON.generate(body), headers)
    if resp.is_a?(Net::HTTPCreated)
      Chef::Log.info("Created keystone service '#{new_resource.service_name}'")
      new_resource.updated_by_last_action(true)
    else
      Chef::Log.error("Unable to create service '#{new_resource.service_name}'")
      Chef::Log.error("Response Code: #{resp.code}")
      Chef::Log.error("Response Message: #{resp.message}")
      new_resource.updated_by_last_action(false)
    end
  elsif resp.is_a?(Net::HTTPOK)
    Chef::Log.info "Service '#{new_resource.service_name}' already exists.. Not creating."
    new_resource.updated_by_last_action(false)
  else
    Chef::Log.error "Unknown response from Keystone Server"
    Chef::Log.error("Response Code: #{resp.code}")
    Chef::Log.error("Response Message: #{resp.message}")
    new_resource.updated_by_last_action(false)
  end
end

action :add_endpoint_template do
  # need to make sure not to add duplicates
end

private
def _build_service_object(svc_name, svc_desc)
  svc_obj = Hash.new
  svc_obj.store("id", svc_name)
  svc_obj.store("description", svc_desc)
  ret = Hash.new
  ret.store("service", svc_obj)
  return ret
end
