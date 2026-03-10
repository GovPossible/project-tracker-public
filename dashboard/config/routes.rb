Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "dashboard#show"
  resources :projects do
    member do
      post :add_reply
      post :nudge
    end
  end
  resources :repos do
    member do
      post :retry_setup
    end
  end

  namespace :api do
    namespace :v1 do
      post "webhooks/mailgun", to: "webhooks#mailgun"
      post "webhooks/twilio", to: "webhooks#twilio"
      post "webhooks/github", to: "webhooks#github"

      resources :projects, only: [:show, :create, :update] do
        collection do
          get :next_available
          get :next_critical
          get :waiting_with_replies
          get :stale_pr_review
          get :human_pending_count
        end
        resources :activities, only: [:create]
        resources :replies, only: [:index, :create] do
          collection do
            patch :mark_read
          end
        end
      end

      resources :repos, only: [:index, :show, :update] do
        collection do
          get :pending_setup
        end
      end
    end
  end
end
