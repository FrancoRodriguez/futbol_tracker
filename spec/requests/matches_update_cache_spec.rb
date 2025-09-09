# spec/requests/matches_update_cache_spec.rb
require "rails_helper"

RSpec.describe "Matches#update cache bust", type: :request do
  let(:user) { create(:user) }
  let(:season) { create(:season) }
  let(:match)  { create(:match, season:) }

  let(:season_key)      { season.id }
  let(:top_winners_key) { [ "top_winners", season_key ] }
  let(:top_mvp_key)     { [ "top_mvp", season_key ] }

  before do
    sign_in user
    Rails.cache.write(top_winners_key, %w[a b c])
    Rails.cache.write(top_mvp_key, %w[x y z])
    allow(Rails.cache).to receive(:delete).and_call_original
  end

  after { Rails.cache.clear }

  describe "PATCH /matches/:id" do
    before do
      patch match_path(match), params: { match: { notes: "actualizado" } }
    end

    it "deletes top_winners cache" do
      expect(Rails.cache).to have_received(:delete).with(top_winners_key).once
    end

    it "deletes top_mvp cache" do
      expect(Rails.cache).to have_received(:delete).with(top_mvp_key).once
    end

    it "redirects after update" do
      expect(response).to have_http_status(:found)
    end

    it "removes value from top_winners cache" do
      expect(Rails.cache.read(top_winners_key)).to be_nil
    end

    it "removes value from top_mvp cache" do
      expect(Rails.cache.read(top_mvp_key)).to be_nil
    end
  end
end
