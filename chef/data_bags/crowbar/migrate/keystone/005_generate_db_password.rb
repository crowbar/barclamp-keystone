# -*- encoding : utf-8 -*-
def upgrade ta, td, a, d
  # Old proposals had passwords created in the cookbook, so we need to migrate
  # them in the proposal and in the role. We use a class variable to set the
  # same password in the proposal and in the role.
  unless defined?(@@keystone_db_password)
    service = ServiceObject.new "fake-logger"
    @@keystone_db_password = service.random_password
  end

  Chef::Search::Query.new.search(:node) do |node|
    unless (node[:keystone][:db][:password] rescue nil).nil?
      unless node[:keystone][:db][:password].empty?
        @@keystone_db_password = node[:keystone][:db][:password]
      end
      node[:keystone][:db].delete('password')
      node.save
    end
  end

  if a['db']['password'].nil? || a['db']['password'].empty?
    a['db']['password'] = @@keystone_db_password
  end

  return a, d
end

def downgrade ta, td, a, d
  return a, d
end
