# encoding: UTF-8
#

require_relative 'spec_helper'

describe 'openstack-identity::server' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::Runner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['endpoints']['identity-bind'] = {
        'host' => '127.0.1.1'
      }
      node.set_unless['openstack']['endpoints']['identity-api'] = {
        'host' => '127.0.1.1',
        'port' => '5000',
        'scheme' => 'https'
      }
      node.set_unless['openstack']['endpoints']['identity-admin'] = {
        'host' => '127.0.1.1',
        'port' => '35357',
        'scheme' => 'https'
      }

      runner.converge(described_recipe)
    end

    include Helpers
    include_context 'identity_stubs'

    it 'runs logging recipe if node attributes say to' do
      node.set['openstack']['identity']['syslog']['use'] = true
      expect(chef_run).to include_recipe('openstack-common::logging')
    end

    it 'does not run logging recipe' do
      expect(chef_run).not_to include_recipe('openstack-common::logging')
    end

    it 'converges when configured to use sqlite db backend' do
      node.set['openstack']['db']['identity']['service_type'] = 'sqlite'
      expect { chef_run }.to_not raise_error
    end

    it 'installs mysql python packages' do
      expect(chef_run).to install_package('python-mysqldb')
    end

    it 'installs postgresql python packages if explicitly told' do
      node.set['openstack']['db']['identity']['service_type'] = 'postgresql'
      expect(chef_run).to install_package('python-psycopg2')
    end

    it 'installs memcache python packages' do
      expect(chef_run).to install_package('python-memcache')
    end

    it 'installs keystone packages' do
      expect(chef_run).to upgrade_package('keystone')
    end

    it 'starts keystone on boot' do
      expect(chef_run).to enable_service('keystone')
    end

    it 'sleep on keystone service enable' do
      expect(chef_run.service('keystone')).to notify(
        'execute[Keystone: sleep]').to(:run)
    end

    describe '/etc/keystone' do
      let(:dir) { chef_run.directory('/etc/keystone') }

      it 'has proper owner' do
        expect(dir.owner).to eq('keystone')
        expect(dir.group).to eq('keystone')
      end

      it 'has proper modes' do
        expect(sprintf('%o', dir.mode)).to eq('700')
      end
    end

    describe '/etc/keystone/ssl' do
      let(:ssl_dir) { '/etc/keystone/ssl' }

      describe 'without pki' do
        it 'does not create' do
          expect(chef_run).not_to create_directory(ssl_dir)
        end
      end

      describe 'with pki' do
        before { node.set['openstack']['auth']['strategy'] = 'pki' }
        let(:dir_resource) { chef_run.directory(ssl_dir) }

        it 'creates' do
          expect(chef_run).to create_directory(ssl_dir)
        end

        it 'has proper owner' do
          expect(dir_resource.owner).to eq('keystone')
          expect(dir_resource.group).to eq('keystone')
        end

        it 'has proper modes' do
          expect(sprintf('%o', dir_resource.mode)).to eq('700')
        end
      end
    end

    it 'deletes keystone.db' do
      expect(chef_run).to delete_file('/var/lib/keystone/keystone.db')
    end

    it 'does not delete keystone.db when configured to use sqlite' do
      node.set['openstack']['db']['identity']['service_type'] = 'sqlite'
      expect(chef_run).not_to delete_file('/var/lib/keystone/keystone.db')
    end

    describe 'pki setup' do
      let(:cmd) { 'keystone-manage pki_setup' }

      describe 'without pki' do
        it 'does not execute' do
          expect(chef_run).to_not run_execute(cmd).with(
            user: 'keystone',
            group: 'keystone'
          )
        end
      end

      describe 'with pki' do
        before { node.set['openstack']['auth']['strategy'] = 'pki' }

        it 'executes' do
          ::FileTest.should_receive(:exists?)
            .with('/etc/keystone/ssl/private/signing_key.pem')
            .and_return(false)

          expect(chef_run).to run_execute(cmd).with(
            user: 'keystone',
            group: 'keystone'
          )
        end

        it 'does not execute when dir exists' do
          ::FileTest.should_receive(:exists?)
            .with('/etc/keystone/ssl/private/signing_key.pem')
            .and_return(true)

          expect(chef_run).not_to run_execute(cmd).with(
            user: 'keystone',
            group: 'keystone'
          )
        end
      end
    end

    describe 'keystone.conf' do
      let(:path) { '/etc/keystone/keystone.conf' }
      let(:resource) { chef_run.template(path) }

      describe 'file properties' do
        it 'has correct owner' do
          expect(resource.owner).to eq('keystone')
          expect(resource.group).to eq('keystone')
        end

        it 'has correct modes' do
          expect(sprintf('%o', resource.mode)).to eq('644')
        end
      end

      it 'notifies keystone restart' do
        expect(resource).to notify('service[keystone]').to(:restart)
      end

      describe '[DEFAULT] section' do
        it 'has admin token' do
          r = line_regexp('admin_token = bootstrap-token')
          expect(chef_run).to render_file(path).with_content(r)
        end

        it 'has bind host' do
          r = line_regexp('bind_host = 127.0.1.1')
          expect(chef_run).to render_file(path).with_content(r)
        end

        describe 'port numbers' do
          ['public_port', 'admin_port'].each do |x|
            it "has #{x}" do
              expect(chef_run).to render_file(path).with_content(/^#{x} = \d+$/)
            end
          end
        end

        describe 'logging verbosity' do
          ['verbose', 'debug'].each do |x|
            it "has #{x} option" do
              r = line_regexp("#{x} = False")
              expect(chef_run).to render_file(path).with_content(r)
            end
          end
        end

        describe 'syslog configuration' do
          log_file = /^log_file = \/\w+/
          log_conf = /^log_config = \/\w+/

          it 'renders log_file correctly' do
            expect(chef_run).to render_file(path).with_content(log_file)
            expect(chef_run).not_to render_file(path).with_content(log_conf)
          end

          it 'renders log_config correctly' do
            node.set['openstack']['identity']['syslog']['use'] = true

            expect(chef_run).to render_file(path).with_content(log_conf)
            expect(chef_run).not_to render_file(path).with_content(log_file)
          end
        end

        it 'has correct endpoints' do
          # values correspond to node attrs set in chef_run above
          pub = line_regexp('public_endpoint = https://127.0.1.1:5000/')
          adm = line_regexp('admin_endpoint = https://127.0.1.1:35357/')

          expect(chef_run).to render_file(path).with_content(pub)
          expect(chef_run).to render_file(path).with_content(adm)
        end
      end

      describe '[memcache] section' do
        it 'has no servers by default' do
          # `Openstack#memcached_servers' is stubbed in spec_helper.rb to
          # return an empty array, so we expect an empty `servers' list.
          r = line_regexp('servers = ')
          expect(chef_run).to render_file(path).with_content(r)
        end

        it 'has servers when hostnames are configured' do
          # Re-stub `Openstack#memcached_servers' here
          hosts = ['host1:111', 'host2:222']
          regex = line_regexp("servers = #{hosts.join(',')}")

          ::Chef::Recipe.any_instance.stub(:memcached_servers).and_return(hosts)
          expect(chef_run).to render_file(path).with_content(regex)
        end
      end

      describe '[sql] section' do
        it 'has a connection' do
          r = /^connection = \w+/
          expect(chef_run).to render_file(path).with_content(r)
        end
      end

      describe '[ldap] section' do
        describe 'optional attributes' do
          optional_attrs = %w{group_tree_dn group_filter user_filter
                              user_tree_dn user_enabled_emulation_dn
                              group_attribute_ignore role_attribute_ignore
                              role_tree_dn role_filter tenant_tree_dn
                              tenant_enabled_emulation_dn tenant_filter
                              tenant_attribute_ignore}

          it 'does not configure attributes' do
            optional_attrs.each do |a|
              enabled = /^#{Regexp.quote(a)} = \w+/
              disabled = /^# #{Regexp.quote(a)} =$/

              expect(chef_run).to render_file(path).with_content(disabled)
              expect(chef_run).not_to render_file(path).with_content(enabled)
            end
          end
        end

        it 'has required attributes' do
          required_attrs = %w{alias_dereferencing allow_subtree_delete
                              dumb_member group_allow_create group_allow_delete
                              group_allow_update group_desc_attribute
                              group_domain_id_attribute group_id_attribute
                              group_member_attribute group_name_attribute
                              group_objectclass page_size query_scope
                              role_allow_create role_allow_delete
                              role_allow_update role_id_attribute
                              role_member_attribute role_name_attribute
                              role_objectclass suffix tenant_allow_create
                              tenant_allow_delete tenant_allow_update
                              tenant_desc_attribute tenant_domain_id_attribute
                              tenant_enabled_attribute tenant_enabled_emulation
                              tenant_id_attribute tenant_member_attribute
                              tenant_name_attribute tenant_objectclass url
                              use_dumb_member user user_allow_create
                              user_allow_delete user_allow_update
                              user_attribute_ignore user_domain_id_attribute
                              user_enabled_attribute user_enabled_default
                              user_enabled_emulation user_enabled_mask
                              user_id_attribute user_mail_attribute
                              user_name_attribute user_objectclass
                              user_pass_attribute}

          required_attrs.each do |a|
            expect(chef_run).to render_file(path).with_content(
              /^#{Regexp.quote(a)} = \w+/)
          end
        end
      end

      describe '[identity] section' do
        it 'configures driver' do
          r = line_regexp('driver = keystone.identity.backends.sql.Identity')
          expect(chef_run).to render_file(path).with_content(r)
        end
      end

      describe '[catalog] section' do
        # use let() to access Helpers#line_regexp method
        let(:templated) do
          str = 'driver = keystone.catalog.backends.templated.TemplatedCatalog'
          line_regexp(str)
        end
        let(:sql) do
          line_regexp('driver = keystone.catalog.backends.sql.Catalog')
        end

        it 'configures driver' do
          expect(chef_run).to render_file(path).with_content(sql)
          expect(chef_run).not_to render_file(path).with_content(templated)
        end

        it 'configures driver with templated backend' do
          node.set['openstack']['identity']['catalog']['backend'] = 'templated'

          expect(chef_run).to render_file(path).with_content(templated)
          expect(chef_run).not_to render_file(path).with_content(sql)
        end
      end

      describe '[token] section' do
        it 'configures driver' do
          r = line_regexp('driver = keystone.token.backends.sql.Token')
          expect(chef_run).to render_file(path).with_content(r)
        end

        it 'sets token expiration time' do
          r = line_regexp('expiration = 86400')
          expect(chef_run).to render_file(path).with_content(r)
        end
      end

      describe '[policy] section' do
        it 'configures driver' do
          r = line_regexp('driver = keystone.policy.backends.sql.Policy')
          expect(chef_run).to render_file(path).with_content(r)
        end
      end

      describe '[signing] section' do
        opts = {
          certfile: '/etc/keystone/ssl/certs/signing_cert.pem',
          keyfile: '/etc/keystone/ssl/private/signing_key.pem',
          ca_certs: '/etc/keystone/ssl/certs/ca.pem',
          key_size: '1024',
          valid_days: '3650',
          ca_password: nil
        }

        describe 'with pki' do
          it 'configures cert options' do
            node.set['openstack']['auth']['strategy'] = 'pki'

            opts.each do |key, val|
              r = line_regexp("#{key} = #{val}")
              expect(chef_run).to render_file(path).with_content(r)
            end
          end
        end

        describe 'without pki' do
          it 'does not configure cert options' do
            opts.each do |key, val|
              expect(chef_run).not_to render_file(path).with_content(
                /^#{key} = /)
            end
          end
        end
      end
    end

    describe 'default_catalog.templates' do
      let(:file) { '/etc/keystone/default_catalog.templates' }

      describe 'without templated backend' do
        it 'does not create' do
          expect(chef_run).not_to render_file(file)
        end
      end

      describe 'with templated backend' do
        before do
          node.set['openstack']['identity']['catalog']['backend'] = 'templated'
        end
        let(:template) { chef_run.template(file) }

        it 'creates' do
          expect(chef_run).to render_file(file)
        end

        it 'has proper owner' do
          expect(template.owner).to eq('keystone')
          expect(template.group).to eq('keystone')
        end

        it 'has proper modes' do
          expect(sprintf('%o', template.mode)).to eq('644')
        end

        it 'notifies keystone restart' do
          expect(template).to notify('service[keystone]').to(:restart)
        end
      end
    end

    describe 'db_sync' do
      let(:cmd) { 'keystone-manage db_sync' }

      it 'runs migrations' do
        expect(chef_run).to run_execute(cmd).with(
          user: 'keystone',
          group: 'keystone'
        )
      end

      it 'does not run migrations' do
        node.set['openstack']['db']['identity']['migrate'] = false
        expect(chef_run).not_to run_execute(cmd).with(
          user: 'keystone',
          group: 'keystone'
        )
      end
    end
  end
end
