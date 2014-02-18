# encoding: UTF-8
#

require_relative 'spec_helper'

describe 'openstack-identity::server' do
  describe 'redhat' do
    let(:runner) { ChefSpec::Runner.new(REDHAT_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) { runner.converge(described_recipe) }

    include_context 'identity_stubs'

    it 'converges when configured to use sqlite db backend' do
      node.set['openstack']['db']['identity']['service_type'] = 'sqlite'
      expect { chef_run }.to_not raise_error
    end

    it 'installs mysql python packages' do
      expect(chef_run).to install_package('MySQL-python')
    end

    it 'installs db2 python packages if explicitly told' do
      node.set['openstack']['db']['identity']['service_type'] = 'db2'

      ['db2-odbc', 'python-ibm-db', 'python-ibm-db-sa'].each do |pkg|
        expect(chef_run).to install_package(pkg)
      end
    end

    it 'installs postgresql python packages if explicitly told' do
      node.set['openstack']['db']['identity']['service_type'] = 'postgresql'
      expect(chef_run).to install_package('python-psycopg2')
    end

    it 'installs memcache python packages' do
      expect(chef_run).to install_package('python-memcached')
    end

    it 'installs keystone packages' do
      expect(chef_run).to upgrade_package('openstack-keystone')
    end

    it 'starts keystone on boot' do
      expect(chef_run).to enable_service('openstack-keystone')
    end
  end
end
