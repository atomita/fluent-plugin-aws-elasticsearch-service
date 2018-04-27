# -*- encoding: utf-8 -*-

require 'rubygems'
require 'fluent/plugin/out_elasticsearch'
require 'aws-sdk-elasticsearchservice'
require 'faraday_middleware/aws_sigv4'


module Fluent::Plugin
  class AwsElasticsearchServiceOutput < ElasticsearchOutput

    Fluent::Plugin.register_output('aws-elasticsearch-service', self)

    config_section :endpoint do
      config_param :region, :string
      config_param :url, :string
      config_param :access_key_id, :string, :default => ""
      config_param :secret_access_key, :string, :default => ""
      config_param :assume_role_arn, :string, :default => nil
      config_param :ecs_container_credentials_relative_uri, :string, :default => nil #Set with AWS_CONTAINER_CREDENTIALS_RELATIVE_URI environment variable value
      config_param :assume_role_session_name, :string, :default => "fluentd"
    end

    # here overrides default value of reload_connections to false because
    # AWS Elasticsearch Service doesn't return addresses of nodes and Elasticsearch client
    # fails to reload connections properly. This ends up "temporarily failed to flush the buffer"
    # error repeating forever. See this discussion for details:
    # https://discuss.elastic.co/t/elasitcsearch-ruby-raises-cannot-get-new-connection-from-pool-error/36252
    config_set_default :reload_connections, false

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
              :credentials => credentials(ep),
              :region => ep[:region]
            }

            host
          end
        end

      {
        hosts: hosts
      }
    end

    def write(chunk)
      super
    end


    private

    #
    # get AWS Credentials
    #
    def credentials(opts)
      calback = lambda do
        credentials = nil
        unless opts[:access_key_id].empty? or opts[:secret_access_key].empty?
          credentials = Aws::Credentials.new opts[:access_key_id], opts[:secret_access_key]
        else
          if opts[:assume_role_arn].nil?
            if opts[:ecs_container_credentials_relative_uri].nil?
              credentials = Aws::SharedCredentials.new({retries: 2}).credentials
              credentials ||= Aws::InstanceProfileCredentials.new.credentials
              credentials ||= Aws::ECSCredentials.new.credentials
            else
              credentials = Aws::ECSCredentials.new({
                credential_path: opts[:ecs_container_credentials_relative_uri]
              }).credentials
            end
          else
            credentials = sts_credential_provider({
                            role_arn: opts[:assume_role_arn],
                            role_session_name: opts[:assume_role_session_name],
                            region: opts[:region]
                          }).credentials
          end
        end
        raise "No valid AWS credentials found." unless credentials.set?
        credentials
      end
      def calback.inspect
        credentials = self.call
        credentials.credentials.inspect
      end
      calback
    end

    def sts_credential_provider(opts)
      # AssumeRoleCredentials is an auto-refreshing credential provider
      @sts ||= Aws::AssumeRoleCredentials.new(opts)
    end

  end


  #
  # monkey patch
  #
  class ElasticsearchOutput
    module Elasticsearch

      module Client
        include ::Elasticsearch::Client
        extend self
      end

      module Transport
        module Transport
          module HTTP
            class Faraday < ::Elasticsearch::Transport::Transport::HTTP::Faraday

              alias :__build_connections_origin_from_aws_elasticsearch_service_output :__build_connections

              # Builds and returns a collection of connections.
              #
              # @return [Connections::Collection]
              # @override
              #
              def __build_connections
                ::Elasticsearch::Transport::Transport::Connections::Collection.new(
                  :connections => hosts.map { |host|
                    host[:protocol]   = host[:scheme] || DEFAULT_PROTOCOL
                    host[:port]     ||= DEFAULT_PORT
                    url               = __full_url(host)

                    ::Elasticsearch::Transport::Transport::Connections::Connection.new(
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
      end
    end

  end
end


#
# monkey patch
#
class FaradayMiddleware::AwsSignersV4

  alias :initialize_origin_from_aws_elasticsearch_service_output :initialize

  def initialize(app, options = nil)
    super(app)

    credentials = options.fetch(:credentials)
    service_name = options.fetch(:service_name)
    region = options.fetch(:region)
    @signer =
      begin
        if credentials.is_a?(Proc)
          signer = lambda do
            Aws::Signers::V4.new(credentials.call, service_name, region)
          end
          def signer.sign(req)
            self.call.sign(req)
          end
          signer
        else
          Aws::Signers::V4.new(credentials, service_name, region)
        end
      end

    @net_http = app.is_a?(Faraday::Adapter::NetHttp)
  end
end
