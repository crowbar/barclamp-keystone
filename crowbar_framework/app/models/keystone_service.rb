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

  def self.allow_multiple_proposals?
    true
  end

  def proposal_dependencies(role)
    answer = []
    if role.default_attributes["keystone"]["sql_engine"] == "mysql"
      answer << { "barclamp" => "mysql", "inst" => role.default_attributes["keystone"]["mysql_instance"] }
    end
    answer
  end

  def create_proposal
    base = super

    nodes = NodeObject.all
    nodes.delete_if { |n| n.nil? or n.admin? }

    base["attributes"]["keystone"]["mysql_instance"] = ""
    begin
      mysqlService = MysqlService.new(@logger)
      # Look for active roles
      mysqls = mysqlService.list_active[1]
      if mysqls.empty?
        # No actives, look for proposals
        mysqls = mysqlService.proposals[1]
      end
      if mysqls.empty?
        base["attributes"]["keystone"]["sql_engine"] = "sqlite"
      else
        base["attributes"]["keystone"]["mysql_instance"] = mysqls[0]
        base["attributes"]["keystone"]["sql_engine"] = "mysql"
      end
    rescue
      @logger.info("Keystone create_proposal: no mysql found")
      base["attributes"]["keystone"]["sql_engine"] = "sqlite"
    end
    
    base["deployment"]["keystone"]["elements"] = {
        "keystone-server" => [ nodes.first[:fqdn] ]
    } unless nodes.nil? or nodes.length ==0

    base[:attributes][:keystone][:service][:token] = '%012d' % rand(1e12)

    base
  end
end

