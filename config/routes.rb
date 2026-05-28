Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Auth
  get    "sign_in"               => "sessions#new",      as: :sign_in
  post   "sign_in"               => "sessions#create"
  get    "sign_in/sent"          => "sessions#sent",     as: :sign_in_sent
  delete "sign_out"              => "sessions#destroy",  as: :sign_out
  get    "sign_in/magic/:token"  => "magic_links#show",  as: :magic_link
  post   "sign_in/magic/:token"  => "magic_links#create", as: :consume_magic_link

  get    "me"                    => "me#show",           as: :me

  # Defines the root path route ("/")
  root "landing#show"
end
