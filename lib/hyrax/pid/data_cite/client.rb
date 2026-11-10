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

        def initialize(host:, username:, password:)
          @host = host
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

        private

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
