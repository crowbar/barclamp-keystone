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

include Opscode::Keystone::Register

action :add_service do
  # need to make sure not to add duplicates
  path = 'v2.0/service/#{new_resource.service_name'
  headers = {
    'X-Auth-Token' => new_resource.token,
    'Content-Type' => 'application/json'
  } 
  resp, data = http.request_get(path,headers)
  if resp == Net::HTTPOK
    path = 'v2.0/service/'
    data_obj = Hash.new
    service_obj = Hash.new
    service_obj.store("id", new_resource.service_name)
    service_obj.store("description", new_resource.service_description)
    data_obj.store("service", service_obj)
    body = JSON.generate(data_obj)
    resp, data = http.send_request('POST', path, body, headers)
    if resp == Net::HTTPOK
      Chef::Log.info("Created keystone service '#{new_resource.service_name}'")
    else
      Chef::Log.error("Unable to create service '#{new_resource.service_name}'")
      Chef::Log.error("Response Code: #{resp.code}")
      Chef::Log.error("Response Message: #{resp.message}")
    end

  else
    Chef::Log.info "Service '#{new_resource.service_name}' already exists.. Not creating."
  end
end

action :add_endpointTemplate do
  # need to make sure not to add duplicates
end
