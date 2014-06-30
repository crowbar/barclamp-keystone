#
# Copyright 2011-2013, Dell
# Copyright 2013-2014, SUSE LINUX Products GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class KeystoneService < PacemakerServiceObject

  def initialize(thelogger)
    super(thelogger)
    @bc_name = "keystone"
  end
# Turn off multi proposal support till it really works and people ask for it.
  def self.allow_multiple_proposals?
    false
  end

  class << self
    def role_constraints
      {
        "keystone-server" => {
          "unique" => false,
          "count" => 1,
          "cluster" => true
        }
      }
    end
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

    base["attributes"][@bc_name]["git_instance"] = find_dep_proposal("git", true)
    base["attributes"][@bc_name]["database_instance"] = find_dep_proposal("database")

    if nodes.size >= 1
      controller = nodes.find { |n| n.intended_role == "controller" } || nodes.first
      base["deployment"]["keystone"]["elements"] = {
        "keystone-server" => [ controller[:fqdn] ]
      }
    end


    base["attributes"][@bc_name][:service][:token] = random_password
    base["attributes"][@bc_name][:db][:password] = random_password

    base
  end

  def validate_proposal_after_save proposal
    validate_one_for_role proposal, "keystone-server"

    if proposal["attributes"][@bc_name]["use_gitrepo"]
      validate_dep_proposal_is_active "git", proposal["attributes"][@bc_name]["git_instance"]
    end

    super
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Keystone apply_role_pre_chef_call: entering #{all_nodes.inspect}")

    server_elements, server_nodes, ha_enabled = role_expand_elements(role, "keystone-server")

    vip_networks = ["admin", "public"]

    dirty = false
    dirty = prepare_role_for_ha_with_haproxy(role, ["keystone", "ha", "enabled"], ha_enabled, server_elements, vip_networks)
    role.save if dirty

    unless all_nodes.empty? || server_elements.empty?
      net_svc = NetworkService.new @logger
      # All nodes must have a public IP, even if part of a cluster; otherwise
      # the VIP can't be moved to the nodes
      server_nodes.each do |node|
        net_svc.allocate_ip "default", "public", "host", node
      end

      allocate_virtual_ips_for_any_cluster_in_networks_and_sync_dns(server_elements, vip_networks)
    end

    @logger.debug("Keystone apply_role_pre_chef_call: leaving")
  end

end

