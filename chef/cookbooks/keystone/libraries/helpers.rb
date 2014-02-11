module KeystoneHelper
  def self.service_URL(node, host, port)
    "#{node[:keystone][:api][:protocol]}://#{host}:#{port}"
  end

  def self.versioned_service_URL(node, host, port)
    service_URL(node, host, port) + '/' + node[:keystone][:api][:version]
  end
end
