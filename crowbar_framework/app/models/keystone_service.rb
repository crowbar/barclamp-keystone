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
    super(thelogger)
    @bc_name = "keystone"
  end
# Turn off multi proposal support till it really works and people ask for it.
  def self.allow_multiple_proposals?
    false
  end

  def proposal_dependencies(role)
    answer = []
    answer << { "barclamp" => "database", "inst" => role.default_attributes["keystone"]["database_instance"] }
    if role.default_attributes[@bc_name]["use_gitrepo"]
      answer << { "barclamp" => "git", "inst" => role.default_attributes[@bc_name]["git_instance"] }
    end
    answer
  end

  def create_proposal
    base = super

    nodes = NodeObject.all
    nodes.delete_if { |n| n.nil? or n.admin? }

    if (base["attributes"][@bc_name]["database_instance"] = validate_has_database_proposal).blank?
      raise(I18n.t('model.service.dependency_missing', :name => @bc_name, :dependson => "database"))
    end

    base["attributes"][@bc_name]["git_instance"] = ""
    begin
      gitService = GitService.new(@logger)
      gits = gitService.list_active[1]
      if gits.empty?
        # No actives, look for proposals
        gits = gitService.proposals[1]
      end
      unless gits.empty?
        base["attributes"][@bc_name]["git_instance"] = gits[0]
      end
    rescue
      @logger.info("#{@bc_name} create_proposal: no git found")
    end

    if nodes.size >= 1
      controller = nodes.find { |n| n.intended_role == "controller" } || nodes.first
      base["deployment"]["keystone"]["elements"] = {
        "keystone-server" => [ controller[:fqdn] ]
      }
    end


    base[:attributes][:keystone][:service][:token] = '%012d' % rand(1e12)

    base
  end

  def validate_proposal_after_save proposal
    validate_has_active_database_proposal
    validate_one_for_role proposal, "keystone-server"

    if proposal["attributes"][@bc_name]["use_gitrepo"]
      validate_dep_proposal_is_active "git", proposal["attributes"][@bc_name]["git_instance"]
    end

    super
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Keystone apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty?

    net_svc = NetworkService.new @logger
    tnodes = role.override_attributes["keystone"]["elements"]["keystone-server"]
    tnodes.each do |n|
      net_svc.allocate_ip "default", "public", "host", n
    end unless tnodes.nil?

    @logger.debug("Keystone apply_role_pre_chef_call: leaving")
  end

end

