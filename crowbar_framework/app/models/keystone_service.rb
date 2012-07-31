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
    answer << { "barclamp" => "database", "inst" => role.default_attributes["keystone"]["sql_instance"] }
    answer
  end

  def create_proposal
    base = super

    nodes = NodeObject.all
    nodes.delete_if { |n| n.nil? or n.admin? }

    base["attributes"]["keystone"]["sql_instance"] = ""
    begin
      databaseService = DatabaseService.new(@logger)
      # Look for active roles
      dbs = databaseService.list_active[1]
      if dbs.empty?
        # No actives, look for proposals
        dbs = databaseService.proposals[1]
      end
      if dbs.empty?
        @logger.info("Keystone create_proposal: no database proposal found")
        base["attributes"]["keystone"]["sql_engine"] = ""
      else
        base["attributes"]["keystone"]["sql_instance"] = dbs[0]
        base["attributes"]["keystone"]["sql_engine"] = "database"
        @logger.info("Keystone create_proposal: using database proposal: '#{dbs[0]}'")
      end
    rescue
      @logger.info("Keystone create_proposal: no mysql found")
      base["attributes"]["keystone"]["sql_engine"] = ""
    end

    # SQLite setups are not supported
    # base["attributes"]["keystone"]["sql_engine"] = "sqlite" if base["attributes"]["keystone"]["sql_engine"] == ""

    base["deployment"]["keystone"]["elements"] = {
        "keystone-server" => [ nodes.first[:fqdn] ]
    } unless nodes.nil? or nodes.length ==0

    base[:attributes][:keystone][:service][:token] = '%012d' % rand(1e12)

    base
  end
end

