# frozen_string_literal: true

module Hyrax
  module Pid
    # Maps a key (typically an identifier type like :doi or :raid, but any
    # symbol an application finds useful, e.g. a resource type) to the
    # Minter that should handle it. Registering a class or callable (rather
    # than a bare instance) lets each minter own its own configuration
    # (credentials, sandbox vs. production, etc.) at resolution time.
    module Registry
      class UnregisteredError < Error; end

      class << self
        # @param key [Symbol, String]
        # @param minter [Hyrax::Pid::Minter, Class, #call] a Minter
        #   instance, a Minter subclass (instantiated with no args), or a
        #   callable returning a configured Minter instance.
        def register(key, minter)
          registrations[key.to_sym] = minter
        end

        # @param key [Symbol, String]
        # @return [Hyrax::Pid::Minter]
        def minter_for(key)
          key = key.to_sym
          minter = registrations.fetch(key) do
            raise UnregisteredError, "No minter registered for #{key.inspect}"
          end

          resolve(minter)
        end

        # @return [Array<Symbol>]
        def registered_keys
          registrations.keys
        end

        def unregister(key)
          registrations.delete(key.to_sym)
        end

        def clear
          registrations.clear
        end

        private

        def registrations
          @registrations ||= {}
        end

        def resolve(minter)
          if minter.is_a?(Class)
            minter.new
          elsif minter.respond_to?(:call)
            minter.call
          else
            minter
          end
        end
      end
    end
  end
end
