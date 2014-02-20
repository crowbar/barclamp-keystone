# encoding: UTF-8
#

require 'chefspec'
require 'chefspec/berkshelf'

LOG_LEVEL = :fatal
SUSE_OPTS = {
  platform: 'suse',
  version: '11.03',
  log_level: LOG_LEVEL
}
REDHAT_OPTS = {
  platform: 'redhat',
  version: '6.3',
  log_level: LOG_LEVEL
}
UBUNTU_OPTS = {
  platform: 'ubuntu',
  version: '12.04',
  log_level: LOG_LEVEL
}

# Helper methods
module Helpers
  # Create an anchored regex to exactly match the entire line
  # (name borrowed from grep --line-regexp)
  #
  # @param [String] str The whole line to match
  # @return [Regexp] The anchored/escaped regular expression
  def line_regexp(str)
    /^#{Regexp.quote(str)}$/
  end
end

shared_context 'identity_stubs' do
  before do
    ::Chef::Recipe.any_instance.stub(:memcached_servers).and_return []
    ::Chef::Recipe.any_instance.stub(:get_password)
      .with('db', anything)
      .and_return('')
    ::Chef::Recipe.any_instance.stub(:get_password)
      .with('user', anything)
      .and_return('')
    ::Chef::Recipe.any_instance.stub(:get_password)
      .with('user', 'user1')
      .and_return('secret1')
    ::Chef::Recipe.any_instance.stub(:secret)
      .with('secrets', 'openstack_identity_bootstrap_token')
      .and_return('bootstrap-token')
  end
end
