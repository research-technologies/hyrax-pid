# frozen_string_literal: true

module Hyrax
  module Pid
    # Result of checking a PID service's saved credentials.
    ConnectionCheck = Struct.new(:ok, :message, keyword_init: true) do
      alias_method :ok?, :ok
    end
  end
end
