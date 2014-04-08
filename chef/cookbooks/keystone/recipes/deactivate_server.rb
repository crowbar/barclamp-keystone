unless node['roles'].include?('keystone-server')
  node["keystone"]["services"]["server"].each do |name|
    service name do
      action [:stop, :disable]
    end
  end
  node.delete('keystone')
  node.save
end
