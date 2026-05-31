class Objective < ApplicationRecord
  belongs_to :workspace
  belongs_to :objectiveable, polymorphic: true, optional: true

  validates :title, presence: true
end
