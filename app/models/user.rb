class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  
  has_many :follower_relationships, foreign_key: :followed_id, class_name: 'Follow'
  has_many :followers, through: :follower_relationships, source: :follower

  has_many :followed_relationships, foreign_key: :follower_id, class_name: 'Follow'
  has_many :followeds, through: :followed_relationships, source: :followed
  before_save :create_user_name

  def follow(user_to_follow)
    unless following?(user_to_follow) && user_to_follow.id == id
      Follow.create(follower: self, followed: user_to_follow)
    end
  end

  def unfollow(user_to_unfollow)
    follow_record = Follow.find_by(follower: self, followed: user_to_unfollow)
    follow_record.destroy if follow_record
  end

  def following?(user)
    Follow.exists?(follower: self, followed: user)
  end      
  
  def create_user_name
    if user_name == nil
      random_string = SecureRandom.hex(4) # 4 bytes = 8 hex digits
      self.user_name = random_string
    end
    if name == nil
      self.name = email
    end
  end
end
