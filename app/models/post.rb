class Post < ApplicationRecord
  validates :body, presence: true
  validates :title, presence: true
end
