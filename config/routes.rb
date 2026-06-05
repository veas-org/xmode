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
  get "sso/start", to: "sso_sessions#start", as: :sso_start
  get "sso/callback/:provider_id", to: "sso_sessions#callback", as: :sso_callback

  resource :app, only: :show, controller: :app
  resource :settings, only: :show, controller: :settings
  resource :admin, only: :show, controller: :admin do
    get :qwen
    post :qwen, action: :ask_qwen
  end
  resources :workspaces, only: %i[new create] do
    member { post :switch }
  end
  resources :projects, except: :destroy do
    member { post :run_sandbox }
  end
  resources :cycles, except: :destroy
  resources :views, controller: :saved_views, only: %i[index show]
  resources :issues, except: :destroy
  resources :events, only: %i[index show]
  resources :event_rules, only: %i[new create edit update]
  get "skills/home", to: "skill_definitions#home", as: :skills_home
  resources :skills, controller: :skill_definitions, except: :destroy do
    collection do
      get :import, action: :new_import
      post :import
    end
    member do
      get :export
      get :source
      patch :source, action: :update_source
      post :release
    end
  end
  get "actions/home", to: "action_definitions#home", as: :actions_home
  resources :actions, controller: :action_definitions, except: :destroy do
    collection do
      get :import, action: :new_import
      post :import
    end
    member do
      get :export
      get :source
      patch :source, action: :update_source
    end
  end
  get "pipelines/home", to: "pipeline_definitions#home", as: :pipelines_home
  resources :pipelines, controller: :pipeline_definitions, except: :destroy do
    collection do
      get :import, action: :new_import
      post :import
    end
    member do
      get :export
      get :source
      patch :source, action: :update_source
      post :run
    end
  end
  resources :pipeline_runs, only: %i[index show] do
    post "run_messages", to: "run_messages#thread", as: :run_messages
    post "run_messages/:id", to: "run_messages#create", as: :run_message
    post "sandbox_sessions/:sandbox_session_id/commands", to: "sandbox_commands#create", as: :sandbox_session_commands
    member do
      post :approve
      post :reject
      post :resume
      post :cancel
    end
  end
  resources :schedules, except: :destroy
  resources :change_requests, only: %i[index show]
  resources :codex_sessions, only: %i[index show create] do
    member { post :message }
  end
  resources :integrations, only: %i[index new create] do
    collection do
      get :github_app
      get :github_app_callback
      post :github_app_manifest
      get :github_app_manifest_callback
    end
    member { post :sync_repositories }
  end
  resources :code_model_profiles, only: %i[create update destroy] do
    member { patch :make_default }
  end
  resources :repository_connections, path: "repositories", only: %i[new create edit update]
  resources :sso_providers, only: %i[new create edit update]
  resources :audit_events, path: "audit", only: :index
  resources :invitations, path: "members", only: %i[index new create]
  get "invites/:token", to: "invitations#show", as: :invitation
  post "invites/:token/accept", to: "invitations#accept", as: :accept_invitation
  resource :billing, only: :show do
    post :checkout
    post :portal
  end
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
