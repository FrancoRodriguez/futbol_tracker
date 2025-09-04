# spec/requests/seasons_controller_spec.rb
# frozen_string_literal: true

require "rails_helper"
require "devise"

RSpec.describe "SeasonsController", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }

  describe "GET /seasons" do
    it "redirect if not logged in" do
      get seasons_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "200 for authenticated and sorted by starts_on desc" do
      sign_in user
      older = create(:season, name: "Temporada 2023/24", starts_on: Date.new(2023, 9, 1))
      newer = create(:season, name: "Temporada 2024/25", starts_on: Date.new(2024, 9, 1))

      get seasons_path
      expect(response).to have_http_status(:ok)
      expect(response.body.index("Temporada 2024/25")).to be < response.body.index("Temporada 2023/24")
    end
  end

  describe "GET /seasons/:id" do
    it "shows the season for authenticated" do
      sign_in user
      season = create(:season)
      get season_path(season)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(season.name)
    end
  end

  describe "GET /seasons/new" do
    it "render for authenticated" do
      sign_in user
      get new_season_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /seasons" do
    let(:params) do
      { season: { name: "Temporada 2025/26", starts_on: "2025-09-01", ends_on: "2026-06-30", active: true } }
    end

    it "create for authenticated" do
      sign_in user
      expect { post seasons_path, params: params }.to change(Season, :count).by(1)
      expect(response).to redirect_to(seasons_path)
    end

    it "DO NOT deactivate other active ones when creating" do
      sign_in user
      other_active = create(:season, name: "Temporada 2024/25", active: true)

      post seasons_path, params: params
      expect(response).to redirect_to(seasons_path)
      expect(other_active.reload.active).to be(true)
    end
  end

  describe "GET /seasons/:id/edit" do
    it "render for authenticated" do
      sign_in user
      season = create(:season)
      get edit_season_path(season)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /seasons/:id" do
    it "update for authenticated" do
      sign_in user
      season = create(:season, name: "S1", active: false)

      patch season_path(season), params: { season: { name: "S1 edit", active: true } }
      expect(response).to redirect_to(seasons_path)
      expect(season.reload.name).to eq("S1 edit")
      expect(season.reload.active).to eq(true)
    end
  end

  describe "PATCH /seasons/:id/activate" do
    it "activate one and deactivate the others" do
      sign_in user
      s1 = create(:season, name: "S1", active: true)
      s2 = create(:season, name: "S2", active: true)
      s3 = create(:season, name: "S3", active: false)

      patch activate_season_path(s3)
      expect(response).to redirect_to(seasons_path)
      expect(s3.reload.active).to be(true)
      expect(s1.reload.active).to be(false)
      expect(s2.reload.active).to be(false)
    end
  end

  describe "PATCH /seasons/:id/deactivate" do
    it "deactivate only that season" do
      sign_in user
      s1 = create(:season, active: true)
      s2 = create(:season, active: true)

      patch deactivate_season_path(s2)
      expect(response).to redirect_to(seasons_path)
      expect(s2.reload.active).to be(false)
      expect(s1.reload.active).to be(true)
    end
  end

  describe "DELETE /seasons/:id" do
    it "eliminates for authenticated" do
      sign_in user
      season = create(:season)
      expect { delete season_path(season) }.to change(Season, :count).by(-1)
      expect(response).to redirect_to(seasons_path)
    end
  end
end
