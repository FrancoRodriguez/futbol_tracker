Rails.application.routes.draw do
  devise_for :users

  resources :matches do
    resources :participations, only: [:new, :create, :edit, :update, :destroy]
  end

  resources :players
  resources :participations, only: [:destroy]
  resources :matches do
    resources :participations, only: [:new, :create, :edit, :update]
  end
  resources :teams, only: [:index]

  root 'matches#index'
end
