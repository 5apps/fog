module Fog
  module Rackspace
    class Storage < Fog::Service

      requires :rackspace_api_key, :rackspace_username

      request_path 'fog/rackspace/requests/cdn'
      request :get_cdn_containers
      request :head_cdn_container
      request :put_cdn_container

      class Mock
        include Utils

        def self.data
          @data ||= Hash.new do |hash, key|
            hash[key] = {}
          end
        end

        def self.reset_data(keys=data.keys)
          for key in [*keys]
            data.delete(key)
          end
        end

        def initialize(options={})
          @rackspace_username = options[:rackspace_username]
          @data = self.class.data[@rackspace_username]
        end

      end

      class Real
        include Utils

        def initialize(options={})
          require 'json'
          credentials = Fog::Rackspace.authenticate(options)
          @auth_token = credentials['X-Auth-Token']

          uri = URI.parse(credentials['X-CDN-Management-Url'])
          @host   = uri.host
          @path   = uri.path
          @port   = uri.port
          @scheme = uri.scheme
          @connection = Fog::Connection.new("#{@scheme}://#{@host}:#{@port}", options[:persistent])
        end

        def reload
          @cdn_connection.reset
        end

        def request(params, parse_json = true)
          begin
            response = @connection.request(params.merge!({
              :headers  => {
                'Content-Type' => 'application/json',
                'X-Auth-Token' => @auth_token
              }.merge!(params[:headers] || {}),
              :host     => @host,
              :path     => "#{@path}/#{params[:path]}",
            }))
          rescue Excon::Errors::Error => error
            raise case error
            when Excon::Errors::NotFound
              Fog::Rackspace::Storage::NotFound.slurp(error)
            else
              error
            end
          end
          if !response.body.empty? && parse_json && response.headers['Content-Type'] =~ %r{application/json}
            response.body = JSON.parse(response.body)
          end
          response
        end

      end
    end
  end
end