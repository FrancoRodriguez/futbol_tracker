Rails.application.routes.draw do
  devise_for :users

  resources :matches do
    resources :participations, only: [:new, :create, :edit, :update, :destroy]
  end

  resources :players do
    collection do
      get :goal_scorers
      get :assist_scorers
    end
  end
  resources :teams, only: [:index]

  resources :participations, only: [:destroy]

  root 'matches#index'
end
