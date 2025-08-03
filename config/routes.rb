Rails.application.routes.draw do
  devise_for :users

  resources :matches do
    resources :participations, only: [:new, :create, :edit, :update, :destroy]
  end
  resources :players do
    collection do
      get :mvp_ranking
      get :win_ranking
    end
  end
  resources :teams, only: [:index]
  resources :participations, only: [:destroy]
  resources :dashboard, only: [:index]

  root 'dashboard#index'
end
