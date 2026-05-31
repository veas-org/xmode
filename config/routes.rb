Rails.application.routes.draw do
  root "home#index"

  get "product", to: "home#product"
  get "pricing", to: "home#pricing"
  get "open-source", to: "home#open_source", as: :open_source
  get "security", to: "home#security"
  get "privacy", to: "home#privacy"
  get "terms", to: "home#terms"
  resources :docs, only: %i[index show]

  get "signup", to: "registrations#new", as: :signup
  post "signup", to: "registrations#create"
  get "login", to: "sessions#new", as: :login
  post "login", to: "sessions#create"
  post "demo/:workspace", to: "sessions#demo", as: :demo_login
  delete "logout", to: "sessions#destroy", as: :logout
  resources :password_resets, only: %i[new create edit update], param: :token

  resource :app, only: :show, controller: :app
  resources :workspaces, only: %i[new create] do
    member { post :switch }
  end
  resources :projects, except: :destroy
  resources :cycles, except: :destroy
  resources :views, controller: :saved_views, only: %i[index show]
  resources :issues, except: :destroy
  resources :events, only: %i[index show]
  resources :skills, controller: :skill_definitions, except: :destroy do
    collection do
      post :import
    end
    member do
      get :export
    end
  end
  resources :actions, controller: :action_definitions, except: :destroy do
    collection do
      post :import
    end
    member do
      get :export
    end
  end
  resources :pipelines, controller: :pipeline_definitions, except: :destroy do
    collection do
      post :import
    end
    member do
      get :export
      post :run
    end
  end
  resources :pipeline_runs, only: %i[index show] do
    member do
      post :approve
      post :reject
      post :resume
      post :cancel
    end
  end
  resources :schedules, except: :destroy
  resources :change_requests, only: %i[index show]
  resources :integrations, only: %i[index new create]
  resource :billing, only: :show
  post "stripe/webhooks", to: "stripe_webhooks#create"

  namespace :webhooks do
    post "events/:workspace_slug/:source", to: "events#create", as: :events
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
