module KeystoneHelper
  def self.service_URL(node, host, port)
    "#{node[:keystone][:api][:protocol]}://#{host}:#{port}"
  end

  def self.versioned_service_URL(node, host, port)
    service_URL(node, host, port) + '/' + node[:keystone][:api][:version] + '/'
  end

  def self.keystone_settings(current_node, cookbook_name)
    # cache the result for each cookbook in an instance variable hash
    unless @keystone_settings && @keystone_settings.include?(cookbook_name)
      node = search_for_keystone(current_node, cookbook_name)

      use_ssl = node["keystone"]["api"]["protocol"] == "https"
      if node[:keystone][:api][:versioned_public_URL].nil? || node[:keystone][:api][:public_URL_host].nil?
        # only compute this if we don't have the right attributes yet; this will
        # be fixed on next run of chef-client on keystone node
        public_host = CrowbarHelper.get_host_for_public_url(node, use_ssl)
      end
      @keystone_settings ||= Hash.new
      @keystone_settings[cookbook_name] = {
        "admin_auth_url" => node[:keystone][:api][:admin_URL] || service_URL(node, node[:fqdn], node["keystone"]["api"]["admin_port"]),
        "public_auth_url" => node[:keystone][:api][:versioned_public_URL] || versioned_service_URL(node, public_host, node["keystone"]["api"]["service_port"]),
        "internal_auth_url" => node[:keystone][:api][:versioned_internal_URL] || versioned_service_URL(node, node[:fqdn], node["keystone"]["api"]["service_port"]),
        "use_ssl" => use_ssl,
        "endpoint_region" => node["keystone"]["api"]["region"],
        "insecure" => use_ssl && node[:keystone][:ssl][:insecure],
        "protocol" => node["keystone"]["api"]["protocol"],
        "public_url_host" => node[:keystone][:api][:public_URL_host] || public_host,
        "internal_url_host" => node[:keystone][:api][:internal_URL_host] || node[:fqdn],
        "service_port" => node["keystone"]["api"]["service_port"],
        "admin_port" => node["keystone"]["api"]["admin_port"],
        "admin_token" => node["keystone"]["service"]["token"],
        "admin_tenant" => node["keystone"]["admin"]["tenant"],
        "admin_user" => node["keystone"]["admin"]["username"],
        "admin_password" => node["keystone"]["admin"]["password"],
        "default_tenant" => node["keystone"]["default"]["tenant"],
        "default_user" => node["keystone"]["default"]["username"],
        "default_password" => node["keystone"]["default"]["password"],
        "service_tenant" => node["keystone"]["service"]["tenant"]
      }

      @keystone_settings[cookbook_name]['service_user'] = current_node[cookbook_name][:service_user]
      @keystone_settings[cookbook_name]['service_password'] = current_node[cookbook_name][:service_password]
    end

    @keystone_settings[cookbook_name]
  end

  private
  def self.search_for_keystone(node, cookbook_name)
    instance = node[cookbook_name][:keystone_instance]

    if @keystone_node && @keystone_node.include?(instance)
      Chef::Log.info("Keystone server found at #{@keystone_node[instance][:keystone][:api][:internal_URL_host]} [cached]")
      return @keystone_node[instance]
    end

    nodes, _, _ = Chef::Search::Query.new.search(:node, "roles:keystone-server AND keystone_config_environment:keystone-config-#{instance}")
    if nodes.first
      keystone_node = nodes.first
      keystone_node = node if keystone_node.name == node.name
    else
      keystone_node = node
    end

    @keystone_node ||= Hash.new
    @keystone_node[instance] = keystone_node

    Chef::Log.info("Keystone server found at #{@keystone_node[instance][:keystone][:api][:internal_URL_host]}")
    return @keystone_node[instance]
  end
end
