module Timeline
    class ProfileController < TimelineController
      before_action :set_details_auth
      before_action :authenticate, only: [:follow_action]

  
      def index
        @id = params[:id]
        @profile_user = User.find_by_user_name(@id)
        if !@profile_user.present?
            redirect_to root_path, alert: "Not found"
            return
        end
        @user_posts = Post.where(user_id: @profile_user.id).order(created_at: :desc)
        @blogs = @user_posts.where(content_type: 'Blog')
        @videos = @user_posts.where(content_type: 'Recording')
        @photos = @user_posts.where(content_type: 'Media')
        @likes = @user_posts.sum(:cached_votes_up)
        @comments = Comment.where(post_id:@user_posts.pluck(:id)).count
        @followers = @profile_user.followers.count
        @followings = @profile_user.followeds.count

        @is_following = false
        @is_self = false
        if  @user_signed_in
          @is_following = current_user.following?(@profile_user)
          @is_self = current_user.id == @profile_user.id
        end
      end

      def post
        @id = params[:id]
        @post = Post.find_by_id(@id)
        if !@post.present?
            redirect_to root_path, alert: "Not found"
            return
        end
      end

      def get_public_post_stats
        id = params[:id]
        @post = Post.find(id)
        @reactions = @post.reactions.group(:reaction).count.transform_keys(&:to_sym)
        @reactions[:thumbs_up]=@post.cached_votes_up
        @reactions[:thumbs_down]=@post.cached_votes_down
        @stats = {
          total_likes: @post.cached_votes_up,
          comments: @post.comments.includes(:user).map { |comment| {id: comment.id, created_at: comment.created_at, user_name: comment.user.name, comment:comment.comment}},
          reactions: @reactions,
          post_id:id,
          post_created_at:@post.created_at
        }
        render partial:"post_public_stats", locals:{stats:@stats}
      end


      def follow_action
        return render json: { status: false, message: 'User not logged in.' } unless current_user.present?
        
        profile_id = params[:profile_id]
        profile_user = User.find_by_user_name(profile_id)
        return render json: { status: false, message: 'Profile not found.' } unless profile_user.present?
        return render json: { status: false, message: 'cannot follow yourself' } if profile_user.id == current_user.id

      
        if current_user.following?(profile_user)
          if current_user.unfollow(profile_user)
            render json: { status: true, message: 'Unfollowed successfully.' }
          else
            render json: { status: false, message: 'Failed to unfollow.' }
          end
        else
          if current_user.follow(profile_user)
            render json: { status: true, message: 'Followed successfully.' }
          else
            render json: { status: false, message: 'Failed to follow.' }
          end
        end
      end

      private
  
      def set_details_auth
        @user_signed_in = current_user.present?
        @is_creator = current_user.present?
      end

      def authenticate
        if !current_user.present?
          redirect_to root_path
        end
      end
    end
  end
  