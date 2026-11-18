# frozen_string_literal: true

module Hyrax
  module Pid
    module Admin
      # Per-tenant settings for PID services (credentials, sandbox vs. production).
      class ServicesController < ::ApplicationController
        helper Rails.application.class.helpers
        with_themed_layout "dashboard"

        before_action { authorize! :manage, Hyrax::Pid::Service }
        before_action :load_service, only: %i[edit update destroy]
        before_action :add_breadcrumbs

        rescue_from ActiveRecord::Encryption::Errors::Base do |error|
          redirect_to admin_services_path, alert: t("hyrax.pid.admin.services.encryption_error", error: error.class.name.demodulize)
        end

        def index
          @definitions = Hyrax::Pid::SERVICES.values
          @services = Hyrax::Pid::Service.where(service: Hyrax::Pid::SERVICES.keys).index_by(&:service)
        end

        def edit; end

        def update
          @service.apply(service_params)
          if @service.save
            redirect_to admin_services_path, notice: t(".success", service: @definition.label)
          else
            render :edit, status: :unprocessable_entity
          end
        end

        def destroy
          @service.destroy if @service.persisted?
          redirect_to admin_services_path, notice: t(".success", service: @definition.label)
        end

        private

        def load_service
          @definition = Hyrax::Pid::SERVICES.fetch(params[:key]) { raise ActionController::RoutingError, "Unknown PID service" }
          @service = Hyrax::Pid::Service.find_or_initialize_by(service: @definition.key)
        end

        def service_params
          params.fetch(:service, {}).permit(*@definition.fields.map(&:name))
        end

        def add_breadcrumbs
          add_breadcrumb t(:"hyrax.controls.home"), main_app.root_path
          add_breadcrumb t(:"hyrax.dashboard.breadcrumbs.admin"), hyrax.dashboard_path
          add_breadcrumb t(:"hyrax.admin.sidebar.configuration"), "#"
          add_breadcrumb t("hyrax.pid.admin.sidebar.services"), admin_services_path
          add_breadcrumb @definition.label, request.path if @definition
        end
      end
    end
  end
end
