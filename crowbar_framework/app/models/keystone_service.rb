# Copyright 2011, Dell 
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

class KeystoneService < ServiceObject

  def initialize(thelogger)
    @bc_name = "keystone"
    @logger = thelogger
  end

  def create_proposal
    base = super

    nodes = NodeObject.all
    nodes.delete_if { |n| n.nil? or n.admin? }

    
    base["deployment"]["keystone"]["elements"] = {
        "keystone-server" => [ nodes.first[:fqdn] ]
    } unless nodes.nil? or nodes.length ==0

    rand_d = rand(100000000)        
    base[:attributes][:keystone][:admin][:token] = '%012d' % rand(1e12)

    base
  end
end

