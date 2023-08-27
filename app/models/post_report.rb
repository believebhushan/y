class PostReport < ApplicationRecord
    belongs_to :post
    belongs_to :user
  
    validates :post, presence: true
    validates :user, presence: true

    enum content: {
        spam: 'spam',
        inappropriate_content: 'inappropriate_content',
        harassment: 'harassment',
        i_dont_like_this: 'i_dont_like_this'
      }
end