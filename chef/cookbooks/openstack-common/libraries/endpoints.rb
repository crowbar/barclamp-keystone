# encoding: UTF-8

#
# Cookbook Name:: openstack-common
# library:: endpoints
#
# Copyright 2012-2013, AT&T Services, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'uri'

module ::Openstack # rubocop:disable Documentation
  # Shortcut to get the full URI for an endpoint. If the 'uri' key isn't
  # set in the endpoint hash, we use the ::Openstack.get_uri_from_mash
  # library routine from the openstack-common cookbook to grab a URI object
  # and construct the URI object from the endpoint parts.
  def endpoint(name)
    ep = endpoint_for name
    if ep && ep['uri']
      ::URI.parse ::URI.encode(ep['uri'])
    elsif ep
      uri_from_hash ep
    end
  end

  # Useful for iterating over the OpenStack endpoints
  def endpoints(&block)
    node['openstack']['endpoints'].each do | name, info |
      block.call(name, info)
    end
  rescue
    nil
  end

  # Instead of specifying the verbose node['openstack']['db'][service],
  # this shortcut allows the simpler and shorter db(service), where
  # service is one of 'compute', 'image', 'identity', 'network',
  # and 'volume'
  def db(service)
    node['openstack']['db'][service]
  rescue
    nil
  end

  # Shortcut to get the SQLAlchemy DB URI for a named service
  def db_uri(service, user, pass) # rubocop:disable MethodLength, CyclomaticComplexity
    info = db(service)
    if info
      host = info['host']
      port = info['port'].to_s
      type = info['service_type']
      name = info['db_name']
      if type == 'pgsql'
      # Normalize to the SQLAlchemy standard db type identifier
        type = 'postgresql'
      end
      case type
      when 'postgresql'
        "#{type}://#{user}:#{pass}@#{host}:#{port}/#{name}"
      when 'mysql'
        "#{type}://#{user}:#{pass}@#{host}:#{port}/#{name}?charset=utf8"
      when 'sqlite'
        # SQLite uses filepaths not db name
        # README(galstrom): 3 slashes is a relative path, 4 slashes is an absolute path
        #  example: info['path'] = 'path/to/foo.db' -- will return sqlite:///foo.db
        #  example: info['path'] = '/path/to/foo.db' -- will return sqlite:////foo.db
        path = info['path']
        "sqlite:///#{path}"
      when 'db2'
        "ibm_db_sa://#{user}:#{pass}@#{host}:#{port}/#{name}?charset=utf8"
      end
    end
  end

  # Return the IPv4 address for the hash.
  #
  # If the bind_interface is set, then return the first IP on the interface.
  # otherwise return the IP specified in the host attribute.
  def address(hash)
    bind_interface = hash['bind_interface'] if hash['bind_interface']

    if bind_interface
      return address_for bind_interface
    else
      return hash['host']
    end
  end

  private

  # Instead of specifying the verbose node['openstack']['endpoints'][name],
  # this shortcut allows the simpler and shorter endpoint(name)
  def endpoint_for(name)
    node['openstack']['endpoints'][name]
  rescue
    nil
  end
end
