# frozen_string_literal: true

module Hyrax
  module Pid
    module DataCite
      # Mints/updates/finds DOIs via the DataCite REST (JSON:API) API.
      # https://support.datacite.org/docs/api
      #
      # The DOI's lifecycle state (draft/registered/findable) is driven by
      # the "event" attribute DataCite expects on create/update, not by a
      # separate call, so #mint always creates a draft and #publish is a
      # thin wrapper over #update that sets event: "publish".
      class Minter < Hyrax::Pid::Minter
        PRODUCTION_HOST = "https://api.datacite.org"
        SANDBOX_HOST = "https://api.test.datacite.org"
        # DataCite's older MDS API, used only to check credentials: unlike the
        # REST API, which treats bad credentials as anonymous on reads, it
        # answers them with a 401.
        PRODUCTION_MDS_HOST = "https://mds.datacite.org"
        SANDBOX_MDS_HOST = "https://mds.test.datacite.org"

        # @param prefix [String] DOI prefix, e.g. "10.1234"
        # @param username [String]
        # @param password [String]
        # @param sandbox [Boolean] use DataCite's test API instead of production
        # @param client [#call] duck-typed HTTP client: responds to
        #   #call(method:, path:, body: nil) and returns a parsed JSON:API
        #   response Hash. Injectable for testing; defaults to a thin
        #   Net::HTTP-based client.
        def initialize(prefix:, username:, password:, sandbox: false, client: nil)
          @prefix = prefix
          @username = username
          @password = password
          @host = sandbox ? SANDBOX_HOST : PRODUCTION_HOST
          @client = client || Hyrax::Pid::DataCite::Client.new(
            host: @host,
            mds_host: sandbox ? SANDBOX_MDS_HOST : PRODUCTION_MDS_HOST,
            username: username,
            password: password
          )
        end

        def identifier_type
          :doi
        end

        # @param metadata [Hash] DataCite attributes (titles, creators,
        #   publisher, publicationYear, types, etc.) minus "doi" and
        #   "prefix", which this adapter supplies.
        # @return [Hyrax::Pid::Identifier]
        def mint(metadata:)
          attributes = metadata.merge(prefix: @prefix)
          response = @client.call(method: :post, path: "/dois", body: doi_payload(attributes))
          build_identifier(response)
        end

        # @param identifier [Hyrax::Pid::Identifier, String]
        # @param metadata [Hash]
        # @return [Hyrax::Pid::Identifier]
        def update(identifier:, metadata:)
          response = @client.call(method: :put, path: "/dois/#{identifier}", body: doi_payload(metadata))
          build_identifier(response)
        end

        # @param identifier [Hyrax::Pid::Identifier, String]
        # @return [Hyrax::Pid::Identifier]
        def find(identifier:)
          response = @client.call(method: :get, path: "/dois/#{identifier}")
          build_identifier(response)
        end

        # Moves a DOI from draft (or registered) to findable.
        # @param identifier [Hyrax::Pid::Identifier, String]
        # @return [Hyrax::Pid::Identifier]
        def publish(identifier:)
          transition(identifier: identifier, event: "publish")
        end

        # Draft -> registered: the DOI resolves but stays out of DataCite's
        # search and metadata feeds.
        # @param identifier [Hyrax::Pid::Identifier, String]
        # @return [Hyrax::Pid::Identifier]
        def register(identifier:)
          transition(identifier: identifier, event: "register")
        end

        # Findable -> registered, e.g. when the work stops being public. A
        # findable DOI can't be deleted, so this is the only way back.
        # @param identifier [Hyrax::Pid::Identifier, String]
        # @return [Hyrax::Pid::Identifier]
        def hide(identifier:)
          transition(identifier: identifier, event: "hide")
        end

        # @param event [String] a DataCite event: "publish", "register" or "hide"
        # @return [Hyrax::Pid::Identifier]
        def transition(identifier:, event:)
          update(identifier: identifier, metadata: {event: event})
        end

        # @return [Hyrax::Pid::ConnectionCheck]
        def check_connection
          unless @client.respond_to?(:check_credentials)
            return Hyrax::Pid::ConnectionCheck.new(ok: false, message: "#{@client.class} can't check credentials")
          end

          @client.check_credentials(prefix: @prefix)
        end

        private

        def doi_payload(attributes)
          {data: {type: "dois", attributes: attributes}}
        end

        def build_identifier(response)
          attributes = response.dig("data", "attributes") || {}
          Hyrax::Pid::Identifier.new(
            value: attributes["doi"],
            type: :doi,
            state: attributes["state"]&.to_sym,
            raw: response
          )
        end
      end
    end
  end
end
