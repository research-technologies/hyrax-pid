# frozen_string_literal: true

module Hyrax
  module Pid
    class Engine < ::Rails::Engine
      isolate_namespace Hyrax::Pid

      ENCRYPTION_KEY_ENV = {
        primary_key: "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY",
        key_derivation_salt: "ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT",
        deterministic_key: "ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"
      }.freeze

      # Prepended so it lands ahead of host catch-all routes (Hyku ends with
      # `get '*alias_path'`), and so hosts don't need a mount line.
      initializer "hyrax_pid.mount" do |app|
        app.routes.prepend do
          mount Hyrax::Pid::Engine, at: "/pid"
        end
      end

      # Run the engine's migrations in place rather than copying them into the
      # host, whose db/migrate may belong to someone else (e.g. Hyku's submodule).
      initializer "hyrax_pid.append_migrations" do |app|
        config.paths["db/migrate"].expanded.each do |path|
          app.config.paths["db/migrate"] << path
        end
      end

      # Service secrets use Active Record encryption. Rails only reads its keys
      # from credentials; also accept them from ENV. Values set here override
      # credentials, so only set the ones that are actually present.
      initializer "hyrax_pid.encryption_keys", before: "active_record_encryption.configuration" do |app|
        ENCRYPTION_KEY_ENV.each do |key, env|
          app.config.active_record.encryption[key] = ENV[env] if ENV[env].present?
        end
      end

      initializer "hyrax_pid.flipflop_features" do
        Flipflop::FeatureLoader.current.append(Hyrax::Pid::Engine.instance)
      end

      config.to_prepare do
        ::Ability.include(Hyrax::Ability::PidAbility)
        ::Ability.ability_logic |= [:pid_abilities]

        sidebar = Hyrax::DashboardController.sidebar_partials[:configuration]
        sidebar << "hyrax/pid/admin/sidebar" unless sidebar.include?("hyrax/pid/admin/sidebar")

        Hyrax::Pid::Registry.register(:doi, -> { Hyrax::Pid::Service.minter_for!("datacite") })

        require "hyrax/pid/registrar"
        # Set one key rather than replacing the hash, so other registrars
        # (e.g. hyrax-doi's :datacite, which Hyku loads) are left alone.
        Hyrax.config.identifier_registrars[:doi] = Hyrax::Pid::Registrar
      end

      # Once, not in to_prepare: a reload would subscribe a second copy. The
      # listener lives in lib/, so reloading doesn't leave a stale class behind.
      config.after_initialize do
        require "hyrax/pid/listener"
        Hyrax.publisher.subscribe(Hyrax::Pid::Listener.new)
      end
    end
  end
end
