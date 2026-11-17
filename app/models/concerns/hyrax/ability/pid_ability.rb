# frozen_string_literal: true

module Hyrax
  module Ability
    # Admin-only: minting calls an external service and writes a permanent
    # identifier onto the record.
    #
    # The Flipflop check is an on/off switch, not access control: Hyrax
    # consults its cookie strategy first, so anyone can force a feature on
    # for themselves. admin? is what actually restricts access.
    module PidAbility
      def pid_abilities
        can :manage, :pid if admin? && Flipflop.mint_doi? && !Flipflop.read_only?
      end
    end
  end
end
