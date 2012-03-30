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
    sql_engine = role.default_attributes["keystone"]["sql_engine"]
    if sql_engine == "mysql" or sql_engine == "postgresql"
      answer << { "barclamp" => sql_engine, "inst" => role.default_attributes["keystone"]["sql_instance"] }
    end
    answer
  end

  def create_proposal
    base = super

    nodes = NodeObject.all
    nodes.delete_if { |n| n.nil? or n.admin? }

    base["attributes"]["keystone"]["sql_instance"] = ""
    begin
      mysqlService = MysqlService.new(@logger)
      # Look for active roles
      mysqls = mysqlService.list_active[1]
      if mysqls.empty?
        # No actives, look for proposals
        mysqls = mysqlService.proposals[1]
      end
      if mysqls.empty?
        @logger.info("Keystone create_proposal: no mysql proposal found")
        base["attributes"]["keystone"]["sql_engine"] = ""
      else
        base["attributes"]["keystone"]["sql_instance"] = mysqls[0]
        base["attributes"]["keystone"]["sql_engine"] = "mysql"
      end
    rescue
      @logger.info("Keystone create_proposal: no mysql found")
      base["attributes"]["keystone"]["sql_engine"] = ""
    end

    if  base["attributes"]["keystone"]["sql_engine"] == ""
      begin
        pgsqlService = PostgresqlService.new(@logger)
        # Look for active roles
        pgsqls = pgsqlService.list_active[1]
        if pgsqls.empty?
          @logger.info("Keystone create_proposal: no active postgresql proposal found")
          # No actives, look for proposals
          pgsqls = pgsqlService.proposals[1]
        end
        if pgsqls.empty?
          @logger.info("Keystone create_proposal: no postgressql proposal found")
          base["attributes"]["keystone"]["sql_engine"] = ""
        else
          @logger.info("Keystone create_proposal: postgresql instance #{pgsqls[0]}")
          base["attributes"]["keystone"]["sql_instance"] = pgsqls[0]
          base["attributes"]["keystone"]["sql_engine"] = "postgresql"
        end
      rescue
        @logger.info("Keystone create_proposal: no postgresql found")
        base["attributes"]["keystone"]["sql_engine"] = ""
      end
    end

    base["attributes"]["keystone"]["sql_engine"] = "sqlite" if base["attributes"]["keystone"]["sql_engine"] == ""
    
    base["deployment"]["keystone"]["elements"] = {
        "keystone-server" => [ nodes.first[:fqdn] ]
    } unless nodes.nil? or nodes.length ==0

    base[:attributes][:keystone][:service][:token] = '%012d' % rand(1e12)

    base
  end
end

