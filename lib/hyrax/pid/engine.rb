# frozen_string_literal: true

module Hyrax
  module Pid
    class Engine < ::Rails::Engine
      isolate_namespace Hyrax::Pid

      # Prepended so it lands ahead of host catch-all routes (Hyku ends with
      # `get '*alias_path'`), and so hosts don't need a mount line.
      initializer "hyrax_pid.mount" do |app|
        app.routes.prepend do
          mount Hyrax::Pid::Engine, at: "/pid"
        end
      end

      initializer "hyrax_pid.flipflop_features" do
        Flipflop::FeatureLoader.current.append(Hyrax::Pid::Engine.instance)
      end

      config.to_prepare do
        ::Ability.include(Hyrax::Ability::PidAbility)
        ::Ability.ability_logic |= [:pid_abilities]

        require "hyrax/pid/registrar"
        # Set one key rather than replacing the hash, so other registrars
        # (e.g. hyrax-doi's :datacite, which Hyku loads) are left alone.
        Hyrax.config.identifier_registrars[:doi] = Hyrax::Pid::Registrar
      end
    end
  end
end
