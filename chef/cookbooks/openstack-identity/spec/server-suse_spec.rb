# encoding: UTF-8
#

require_relative 'spec_helper'

describe 'openstack-identity::server' do
  describe 'suse' do
    let(:runner) { ChefSpec::Runner.new(SUSE_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) { runner.converge(described_recipe) }

    include_context 'identity_stubs'

    it 'converges when configured to use sqlite db backend' do
      node.set['openstack']['db']['identity']['service_type'] = 'sqlite'
      expect { chef_run }.to_not raise_error
    end

    it 'installs mysql python packages' do
      expect(chef_run).to install_package('python-mysql')
    end

    it 'installs postgresql python packages if explicitly told' do
      node.set['openstack']['db']['identity']['service_type'] = 'postgresql'
      expect(chef_run).to install_package('python-psycopg2')
    end

    it 'installs memcache python packages' do
      expect(chef_run).to install_package('python-python-memcached')
    end

    it 'installs keystone packages' do
      expect(chef_run).to upgrade_package('openstack-keystone')
    end

    it 'starts keystone on boot' do
      expect(chef_run).to enable_service('openstack-keystone')
    end

    describe '/etc/keystone' do
      let(:dir) { chef_run.directory('/etc/keystone') }

      it 'has proper owner' do
        expect(dir.owner).to eq('openstack-keystone')
        expect(dir.group).to eq('openstack-keystone')
      end
    end

    describe '/etc/keystone/ssl' do
      before { node.set['openstack']['auth']['strategy'] = 'pki' }
      let(:dir) { chef_run.directory('/etc/keystone/ssl') }

      it 'has proper owner' do
        expect(dir.owner).to eq('openstack-keystone')
        expect(dir.group).to eq('openstack-keystone')
      end
    end

    it 'deletes keystone.db' do
      expect(chef_run).to delete_file('/var/lib/keystone/keystone.db')
    end

    describe 'keystone.conf' do
      let(:template) { chef_run.template '/etc/keystone/keystone.conf' }

      it 'has proper owner' do
        expect(template.owner).to eq('openstack-keystone')
        expect(template.group).to eq('openstack-keystone')
      end
    end

    describe 'default_catalog.templates' do
      before do
        node.set['openstack']['identity']['catalog']['backend'] = 'templated'
      end
      let(:template) do
        chef_run.template('/etc/keystone/default_catalog.templates')
      end

      it 'has proper owner' do
        expect(template.owner).to eq('openstack-keystone')
        expect(template.group).to eq('openstack-keystone')
      end
    end
  end
end
