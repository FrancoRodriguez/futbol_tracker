# config/routes.rb
Rails.application.routes.draw do
  devise_for :users

  resources :matches do
    member { post :autobalance }

    resources :participations, only: [:create, :update, :destroy] do
      collection { post :bulk_create }  # <-- AQUÍ va
    end
  end

  resources :players do
    collection do
      get :mvp_ranking
      get :win_ranking
    end
  end

  resources :teams, only: [:index]

  # ⚠️ Este top-level suele ser innecesario y puede chocar con el anidado:
  # resources :participations, only: [:destroy]

  resources :dashboard, only: [:index]
  root 'dashboard#index'
end
