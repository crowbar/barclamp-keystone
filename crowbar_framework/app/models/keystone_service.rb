# Copyright 2012, Dell 
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

  def proposal_dependencies(prop_config)
    answer = []
    hash = prop_config.config_hash
    if hash["keystone"]["sql_engine"] == "mysql"
      answer << { "barclamp" => "mysql", "inst" => hash["mysql_instance"] }
    end
    answer
  end

  def create_proposal(name)
    base = super(name)

    nodes = Node.all
    nodes.delete_if { |n| n.nil? or n.is_admin? }
    if nodes.size >= 1
      add_role_to_instance_and_node(nodes[0].name, base.name, "keystone-server")
    end

    hash = base.current_config.config_hash
    hash["keystone"]["mysql_instance"] = ""
    begin
      mysql = Barclamp.find_by_name("mysql")
      # Look for active roles
      mysqls = mysql.active_proposals
      if mysqls.empty?
        # No actives, look for proposals
        mysqls = mysql.proposals
      end
      unless mysqls.empty?
        hash["keystone"]["mysql_instance"] = mysqls[0].name
      end
      hash["keystone"]["sql_engine"] = "mysql"
    rescue
      @logger.info("Keystone create_proposal: no mysql found")
      hash["keystone"]["sql_engine"] = "mysql"
    end

    hash["keystone"]["service"]["token"] = '%012d' % rand(1e12)

    base.current_config.config_hash = hash

    base
  end
end

