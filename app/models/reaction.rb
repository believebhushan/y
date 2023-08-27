class Reaction < ApplicationRecord
    belongs_to :post
    belongs_to :user
  
    validates :post, presence: true
    validates :user, presence: true
    enum reaction: {
        heart: 'heart',
        star_struck: 'star_struck',
        rocket: 'rocket'
    }
end
