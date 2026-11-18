# frozen_string_literal: true

Hyrax::Pid::Engine.routes.draw do
  # By id alone, so one route serves every work type.
  post "works/:id/mint_doi", to: "dois#create", as: :mint_doi

  namespace :admin do
    resources :services, only: %i[index edit update destroy], param: :key
  end
end
