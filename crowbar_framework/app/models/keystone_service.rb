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
    hash = base.current_config.config_hash
    @logger.debug("Keystone create_proposal: hacking up default proposal config")
    hash["keystone"] ||= {}
    hash["keystone"]["service"] ||= {}
    hash["keystone"]["service"]["token"] = '%012d' % rand(1e12)
    hash["keystone"]["sql_engine"] = "sqlite"
    if mysql = Barclamp.find_by_name("mysql")
      mysqls = (mysql.active_proposals + mysql.proposals)
      unless mysqls.empty?
        hash["keystone"]["sql_engine"] = "mysql"
        hash["keystone"]["mysql_instance"] = mysqls[0].name
      else
        @logger.info("Keystone create_proposal: no mysql found.  Will use sqlite instead.")
      end
    end
    @logger.debug("Keystone create_proposal: will save #{hash.inspect}")
    base.current_config.config_hash = hash
    raise("Keystone create_proposal: Did not save updated info!") unless hash == base.current_config.config_hash
    node = Node.first(:conditions => [ "admin = ?", false])
    add_role_to_instance_and_node(node.name, base.name, "keystone-server") if node
    base
  end
end

