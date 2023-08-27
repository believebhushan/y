class Post < ApplicationRecord
        acts_as_votable
        belongs_to :user
        has_many :comments, dependent: :destroy
        has_many :reactions, dependent: :destroy
      
        validates :user, presence: true
    
        scope :sparks_choice_posts, -> { where(user_type: :admin).order(created_at: :desc) }
        scope :hot_posts, -> { where.not(user_type: :admin).where("cached_votes_up > ? AND cached_votes_up <= ?" ,2,5)}
        scope :trending_posts, -> { where.not(user_type: :admin).where("cached_votes_up > ?", 5)}
        scope :fresh_posts, -> { where("cached_votes_up <= ?",2).where.not(user_type: :admin).order(created_at: :desc) }
        scope :pinned_active, -> {where(is_pinned:true).where("pin_start_time <= ? AND pin_end_time >= ?", Time.zone.now.in_time_zone("Asia/Kolkata"), Time.zone.now.in_time_zone("Asia/Kolkata"))}
        scope :pinned_inactive, -> {where(is_pinned:true).where.not("pin_start_time <= ? AND pin_end_time >= ?", Time.zone.now.in_time_zone("Asia/Kolkata"), Time.zone.now.in_time_zone("Asia/Kolkata"))}
    
    
    
        enum user_type: {
            admin:0,
            user:1,
            teacher:2
        }
    
        scope :admins, -> { where(user_type: :admin) }
        scope :users, -> { where(user_type: :user) }
        scope :teachers, -> { where(user_type: :teacher) }
    
        enum pinned_tab: {
            fresh:0,
            hot:1,
            trending:2,
            sparks_choice:3
        }
    
        enum status: {
            active:0,
            inactive:1,
            deleted:2
        }
    
        def tags_raw=(value)
            self.tags = value.to_s.downcase.split(",").map(&:strip)
        end
    
    
    
        def tags_raw
            tags.join(",")
        end
    
        def created_for
            info = self.user.class.name
            info = 'Admin' if info == 'Employee'
            info
        end
    
        def created_by
            info_map = {
              admin: "Admin",
              user: "Self",
              teacher: "Teacher"
            }
            info_map[self.user_type.to_sym]
        end
    
        def reactions_stats
            @reactions = self.reactions.group(:reaction).count.transform_keys(&:to_sym)
            @reactions
        end
    
        def postive_reactions
            @reactions = self.reactions.group(:reaction).count.transform_keys(&:to_sym)
            @reactions[:thumbs_up]=self.cached_votes_up
            @reactions
        end
end
