# app/models/duel_vote.rb
class DuelVote < ApplicationRecord
  belongs_to :match
  belongs_to :player

  validates :voter_key, presence: true
end
