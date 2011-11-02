begin
  require 'json'
rescue LoadError
  Chef::Log.info("Missing gem 'json'")
end

module Opscode
  module Keystone
    module Register
      def client
        @client ||= Net::HTTP.new(new_resource.url, new_resource.port)
      end
    end
  end
end
