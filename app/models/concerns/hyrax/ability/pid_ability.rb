# frozen_string_literal: true

module Hyrax
  module Ability
    # Admin-only: managing service credentials, and minting, which calls an
    # external service and writes a permanent identifier onto the record.
    #
    # The Flipflop check is an on/off switch, not access control: Hyrax
    # consults its cookie strategy first, so anyone can force a feature on
    # for themselves. admin? is what actually restricts access.
    module PidAbility
      def pid_abilities
        return unless admin?

        can :manage, Hyrax::Pid::Service
        can :manage, :pid if Flipflop.mint_doi? && !Flipflop.read_only? && Hyrax::Pid::Service.configured?("datacite")
      end
    end
  end
end
