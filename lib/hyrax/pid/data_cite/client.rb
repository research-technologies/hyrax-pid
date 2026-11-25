# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module Hyrax
  module Pid
    module DataCite
      # Thin Net::HTTP wrapper over DataCite's JSON:API, used as the
      # default #call-able client for Hyrax::Pid::DataCite::Minter.
      class Client
        class RequestError < Hyrax::Pid::Error; end

        # @param host [String] REST API host
        # @param mds_host [String, nil] MDS API host, only needed for #check_credentials
        def initialize(host:, username:, password:, mds_host: nil)
          @host = host
          @mds_host = mds_host
          @username = username
          @password = password
        end

        # @param method [Symbol] :get, :post, or :put
        # @param path [String]
        # @param body [Hash, nil]
        # @return [Hash] parsed JSON response body
        def call(method:, path:, body: nil)
          uri = URI.join(@host, path)
          request = build_request(method: method, uri: uri, body: body)

          response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
            http.request(request)
          end

          raise RequestError, "#{response.code} #{response.message}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

          JSON.parse(response.body)
        end

        # Two checks, since no single DataCite call covers both:
        #
        # 1. Credentials: HEAD on MDS's DOI list. MDS checks credentials before
        #    anything else there, so wrong ones get a 401. (Not per-DOI paths:
        #    MDS answers those "404 DOI not found" whatever the credentials.
        #    Not the REST API: it treats bad credentials as anonymous on reads.)
        #    HEAD, so a large repository's DOI list isn't downloaded.
        # 2. Prefix: the repository's public REST record lists its prefixes.
        #
        # @param prefix [String]
        # @return [Hyrax::Pid::ConnectionCheck]
        def check_credentials(prefix:)
          raise ArgumentError, "no mds_host given" unless @mds_host

          credentials = check_mds_credentials
          return credentials unless credentials.ok?

          check_prefix(prefix)
        rescue SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError => e
          Hyrax::Pid::ConnectionCheck.new(ok: false, message: "Couldn't reach DataCite: #{e.message}")
        end

        private

        def check_mds_credentials
          uri = URI.join(@mds_host, "/doi")
          request = Net::HTTP::Head.new(uri)
          request.basic_auth(@username, @password)
          response = start(uri) { |http| http.request(request) }

          case response.code.to_i
          when 200..299
            Hyrax::Pid::ConnectionCheck.new(ok: true, message: "DataCite accepted the credentials.")
          when 401
            Hyrax::Pid::ConnectionCheck.new(ok: false, message: "DataCite rejected the repository account ID or password.")
          else
            Hyrax::Pid::ConnectionCheck.new(ok: false, message: "DataCite answered #{response.code} when checking the credentials.")
          end
        end

        def check_prefix(prefix)
          uri = URI.join(@host, "/clients/#{URI.encode_www_form_component(@username)}")
          response = start(uri) { |http| http.request(Net::HTTP::Get.new(uri)) }

          unless response.is_a?(Net::HTTPSuccess)
            return Hyrax::Pid::ConnectionCheck.new(
              ok: false, message: "DataCite accepted the credentials, but answered #{response.code} looking up repository #{@username}."
            )
          end

          prefixes = Array(JSON.parse(response.body).dig("data", "relationships", "prefixes", "data")).map { |p| p["id"].to_s.downcase }
          if prefixes.include?(prefix.to_s.strip.downcase)
            Hyrax::Pid::ConnectionCheck.new(ok: true, message: "DataCite accepted the credentials, and prefix #{prefix} belongs to repository #{@username}.")
          else
            Hyrax::Pid::ConnectionCheck.new(
              ok: false,
              message: "DataCite accepted the credentials, but prefix #{prefix} isn't assigned to repository #{@username} " \
                       "(it has: #{prefixes.empty? ? 'none' : prefixes.join(', ')})."
            )
          end
        rescue JSON::ParserError
          Hyrax::Pid::ConnectionCheck.new(ok: false, message: "DataCite accepted the credentials, but its repository record couldn't be read.")
        end

        def start(uri, &block)
          Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 10, &block)
        end

        def build_request(method:, uri:, body:)
          request_class = {get: Net::HTTP::Get, post: Net::HTTP::Post, put: Net::HTTP::Put}.fetch(method)
          request = request_class.new(uri)
          request.basic_auth(@username, @password)
          request["Content-Type"] = "application/vnd.api+json"
          request.body = body.to_json if body
          request
        end
      end
    end
  end
end
