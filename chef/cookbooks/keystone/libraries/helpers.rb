module KeystoneHelper
  def self.service_URL(node, host, port)
    "#{node[:keystone][:api][:protocol]}://#{host}:#{port}"
  end

  def self.versioned_service_URL(node, host, port)
    service_URL(node, host, port) + '/' + node[:keystone][:api][:version] + '/'
  end

  def self.keystone_settings(node)
    use_ssl = node["keystone"]["api"]["protocol"] == "https"
    if node[:keystone][:api][:versioned_public_URL].nil? || node[:keystone][:api][:public_URL_host].nil?
      # only compute this if we don't have the right attributes yet; this will
      # be fixed on next run of chef-client on keystone node
      public_host = CrowbarHelper.get_host_for_public_url(node, use_ssl)
    end

    {
      "admin_auth_url" => node[:keystone][:api][:versioned_admin_URL] || versioned_service_URL(node, node[:fqdn], node["keystone"]["api"]["admin_port"]),
      "public_auth_url" => node[:keystone][:api][:versioned_public_URL] || versioned_service_URL(node, public_host, node["keystone"]["api"]["service_port"]),
      "internal_auth_url" => node[:keystone][:api][:versioned_internal_URL] || versioned_service_URL(node, node[:fqdn], node["keystone"]["api"]["service_port"]),
      "use_ssl" => use_ssl,
      "insecure" => use_ssl && keystone[:keystone][:ssl][:insecure],
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
  end
end
