# -*- encoding: utf-8 -*-

require 'rubygems'
require 'fluent/plugin/out_elasticsearch'
require 'aws-sdk'
require 'faraday_middleware'
require 'faraday_middleware/aws_signers_v4'


module Fluent
  class AwsElasticsearchServiceOutput < ElasticsearchOutput

    Plugin.register_output('aws-elasticsearch-service', self)

    config_section :endpoint do
      config_param :region, :string
      config_param :url, :string
      config_param :access_key_id, :string, :default => ""
      config_param :secret_access_key, :string, :default => ""
    end


    #
    # @override
    #
    def get_connection_options
      raise "`endpoint` require." if @endpoint.empty?
      
      hosts =
        begin
          @endpoint.map do |ep|
            uri = URI(ep[:url])
            host = %w(user password path).inject(host: uri.host, port: uri.port, scheme: uri.scheme) do |hash, key|
              hash[key.to_sym] = uri.public_send(key) unless uri.public_send(key).nil? || uri.public_send(key) == ''
              hash
            end

            host[:aws_elasticsearch_service] = {
              :credentials => credentials(ep[:access_key_id], ep[:secret_access_key]),
              :region => ep[:region]
            }
            
            host
          end
        end
      
      {
        hosts: hosts
      }
    end


    private

    #
    # get AWS Credentials
    #
    def credentials(access_key, secret_key)
      @credentials ||= {}
      @credentials[access_key] ||= {}
      @credentials[access_key][secret_key] ||=
        begin
          credentials = nil
          if access_key.empty? or secret_key.empty?
            credentials   = Aws::InstanceProfileCredentials.new.credentials
            credentials ||= Aws::SharedCredentials.new.credentials
          end
          credentials ||= Aws::Credentials.new access_key, secret_key
          credentials
        end
    end


    #
    # monkey patch
    #
    class ElasticsearchOutput::Elasticsearch::Transport::Transport::HTTP::Faraday

      alias :__build_connections_origin_from_aws_elasticsearch_service_output :__build_connections

      # Builds and returns a collection of connections.
      #
      # @return [Connections::Collection]
      # @override
      #
      def __build_connections
        Elasticsearch::Transport::Transport::Connections::Collection.new(
          :connections => hosts.map { |host|
            host[:protocol]   = host[:scheme] || DEFAULT_PROTOCOL
            host[:port]     ||= DEFAULT_PORT
            url               = __full_url(host)

            Elasticsearch::Transport::Transport::Connections::Connection.new(
              :host => host,
              :connection => ::Faraday::Connection.new(
                url,
                (options[:transport_options] || {}),
                &__aws_elasticsearch_service_setting(host, &@block)
              ),
              :options => host[:connection_options]
            )
          },
          :selector_class => options[:selector_class],
          :selector => options[:selector]
        )
      end

      def __aws_elasticsearch_service_setting(host, &block)
        lambda do |faraday|
          if host[:aws_elasticsearch_service]
            faraday.request :aws_signers_v4,
                            credentials: host[:aws_elasticsearch_service][:credentials],
                            service_name: 'es',
                            region: host[:aws_elasticsearch_service][:region]
          end
          block.call faraday
        end
      end
    end

  end
end
