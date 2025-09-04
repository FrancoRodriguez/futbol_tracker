# config/routes.rb
Rails.application.routes.draw do
  devise_for :users

  resources :matches do
    member { post :autobalance }

    resource :duel_vote, only: [ :create ], controller: "duel_votes"
    resources :participations, only: [ :create, :update, :destroy ] do
      collection { post :bulk_create }  # <-- AQUÍ va
    end
  end

  resources :players do
    collection do
      get :mvp_ranking
      get :win_ranking
    end
  end

  resources :teams, only: [ :index ]

  resources :seasons do
    member do
      patch :activate
      patch :deactivate
    end
  end

  resources :dashboard, only: [ :index ]
  root "dashboard#index"
end
