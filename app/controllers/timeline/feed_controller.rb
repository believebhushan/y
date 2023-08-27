module Timeline
    class FeedController < TimelineController

      before_action :authenticate_user

      def index
        if current_user.present?
        else
          redirect_to  root_path , notice: "You're not authorized to perform this action"
        end
      end

      def list_posts
        @post_type = params[:post_type]
        @post_category = params[:post_cateogry]
        
        post_type_mapping={
          'fresh' => :fresh_posts,
          'trending' => :trending_posts,
          'hot' => :hot_posts,
          'sparks_choice' => :sparks_choice_posts
        }
        content_type_mapping={
          'video':'Recording',
          'blog':'Blog',
          'image':'Media'
        }

        pinned_active_current_tab = Post.pinned_active.where(pinned_tab: Post.pinned_tabs[@post_type])
        pinned_inactive_current = Post.send(post_type_mapping[@post_type]).pinned_inactive.where(pinned_tab:Post.pinned_tabs[@post_type])
        pinned_active_other = Post.send(post_type_mapping[@post_type]).pinned_active.where.not(pinned_tab:Post.pinned_tabs[@post_type])


        post_scope = Post.send(post_type_mapping[@post_type]).where.not(id:pinned_active_current_tab.pluck(:id)+ pinned_active_other.pluck(:id))
        

        content_type = content_type_mapping[@post_category.to_sym]
        if content_type.present?
          post_scope = post_scope.where(content_type: content_type)
          pinned_active_current_tab = pinned_active_current_tab.where(content_type: content_type)
        end

        @posts= @post_type == 'sparks_choice' ? post_scope : pinned_active_current_tab + post_scope
        
        default_per_page = 10
        @posts = Kaminari.paginate_array(@posts).page(params[:page]).per(params[:per_page] || default_per_page)

        render partial: "posts_feed", locals: { posts: @posts }
      end

      def get_post_stats
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
        render partial:"post_details", locals:{stats:@stats}
      end

      def get_user_posts_stats
        @posts = Post.users.where(user: current_user).order(created_at: :desc)
        @videos = @posts.select { |post| post.spark_post_content.content_type == "Recording" }
        @blogs =  @posts.select { |post| post.spark_post_content.content_type == "Blog" }
        @images=  @posts.select { |post| post.spark_post_content.content_type == "Media" }
        
        @stats = {
          "posts": {
            "total": @posts.count,
            "total_comments": Comment.where(spark_post_id: @posts.pluck(:id)).count,
            "reactions": calculate_reaction_count(@posts)
          }
        }
        
        render partial:"user_stats", locals:{stats:@stats, videos: @videos[0,2], photos: @images[0,2], blogs: @blogs[0,2]}
      end
      
      def calculate_reaction_count(posts)
        reactions = {}
        posts.each do |post|
          post.spark_post_reactions.group(:reaction).count.each do |reaction, count|
            reactions[reaction] ||= 0
            reactions[reaction] += count
          end
          reactions[:thumbs_up] ||= 0
          reactions[:thumbs_up]+=post.cached_votes_up
        end
        reactions
      end 

      def add_reaction
        post_id = params[:post_id]
        reaction_type = params[:reaction_type]
        @post = Post.find(post_id)
        
        if ['thumbs_up', 'thumbs_down'].include?(reaction_type)
          if reaction_type == 'thumbs_up'
            @post.liked_by(current_user)
          elsif reaction_type == 'thumbs_down'
            @post.disliked_by(current_user)
          end
        else
          @reaction = @post.reactions.find_by(user: current_user, reaction: reaction_type)
          if @reaction.present?
            @reaction.destroy
          else
            @post.reactions.create(reaction: reaction_type, user: current_user)
          end
        end
        
        render json: { data: "success" }
      end
      

      def add_comment
        post_id=params[:post_id]
        comment=params[:comment]
        byebug
        @post=Post.find(post_id)
        @comments=@post.comments.where(user:current_user,comment:comment)
        if @comments.present?
          @comments.delete_all
        else
          @post.comments.create(user:current_user,comment:comment)
        end
        render json:{status:true}
      end

      def get_post
        id=params[:post_id]
        @post=Post.find(id)
        render partial:"post_modal_content", locals:{post:@post}
      end

      def create_image_post
        user_id = params[:user_id]
        post_image = params[:post_image].tempfile
        post_description = params[:post_description]
        user = User.find(user_id)
        is_user_banned=is_user_banned(user_id)
        if is_user_banned
          render json: { status: false, message: 'You have tried to post inappropriate content before. You cannot upload photos. Please contact if you think it is a mistake.' }
          return
        end
        ActiveRecord::Base.transaction do
          post = Post.new(user: user, user_type: :user)
          content_file = File.new(post_image)
          require 'uri'
          require 'net/http'
          file_name ="#{Time.now.to_i}#{params[:post_image].original_filename}"
          file_url = "https://sg.storage.bunnycdn.com/posttree/posts/#{file_name}"
          uploaded_url = "https://plant.b-cdn.net/posts/#{file_name}"
          
          url = URI(file_url)
          
          http = Net::HTTP.new(url.host, url.port)
          http.use_ssl = true
          
          request = Net::HTTP::Put.new(url)
          request["content-type"] = 'application/octet-stream'
          request["AccessKey"] = '1aa76ab1-bf25-455d-b9ce3bddb783-e659-40dc'
          request.body = content_file.read
          response = http.request(request)
          if response.code.to_i == 201
            post.url = uploaded_url
            post.title = post_description
            post.content_type = "Media"
            post.save
          end
        
          if post.persisted?
            render json: { status: true, data: { url: post.url, post_id: post.id, content_id: post.id } }
          else
            raise ActiveRecord::Rollback # Rollback transaction if content creation fails
            render json: { status: false, message: 'Failed to create post content' }
          end
        end
      end   

               

      def create_post_violation_report
        user_id = params[:user_id]
        user=User.find(user_id)
        post_image = params[:post_image].tempfile
        report = JSON.parse(params[:report]).to_a
        timestamp = Time.zone.now.flattened
      
        File.open(post_image, 'r') do |file|
          s3 = Aws::S3::Resource.new(region: ENV['AWS_REGION'])
          path_to_upload = "users/spark_post_violations/#{user.try(:name).slugify}-#{user_id}/-#{timestamp}"
          file_extension = File.extname(file.path).downcase
      
          case file_extension
          when '.jpeg', '.jpg', '.png'
            path_to_upload += '.jpeg'
            content_type = 'image/jpeg'
          when '.gif'
            path_to_upload += '.gif'
            content_type = 'image/gif'
          else
            render json: { status: false, message: 'Unsupported file type' }
            return
          end
      
          obj = s3.bucket(ENV['S3_BUCKET']).object(path_to_upload)
          obj.upload_file(file.path, content_type: content_type, acl: 'public-read')
          content_url = obj.public_url
                
          reason = report.find {|r| r["type"]!= 'Neutral' &&  r["type"]!= 'Drawing' && r["probability"].to_f > 0.5}
     


          if !reason.present?
            render json: { status: false ,data:{message:"Could Not Find Any Violating Content"}}
            return
          end

          spark_post_violation = PostContentViolation.new(user_id:user_id,reason_category:reason["type"].downcase,percentage:reason["probability"],report:report,status: :system_rejected,url:content_url)
          if spark_post_violation.save
            render json: { status: true, data:{id:spark_post_violation.id} }
            return
          else
            message = spark_post_violation.errors.full_messages.join(' ') 
            render json: { status: false, data:{message:message} }
          end
          
        end
      end   

      def create_video_post
        ActiveRecord::Base.transaction do
          user_id = params[:user_id]
          recording_id = params[:recording_id]
      
          post = Post.create(user_id: user_id, user_type: :user)
          recording = Recording.find(recording_id)
      
          spark_post_content = PostContent.create(
            spark_post: post,
            pseudonym: recording,
            url: recording.get_url[:link],
            title: recording.title,
            content_type: 'Recording'
          )
      
          if spark_post_content.persisted?
            create_user_interaction(current_user.id, 'video_post_count')
            render json: { status: true, data: { post_id: post.id, content_id: spark_post_content.id } }
          else
            raise ActiveRecord::Rollback # Rollback transaction if content creation fails
            render json: { status: false, message: 'Failed to create post content' }
          end
        end
      end      

      def create_blog_post
        ActiveRecord::Base.transaction do
          user_id = params[:user_id]
          blog_id = params[:blog_id]
      
          post = Post.create(user_id: user_id, user_type: :user)
          blog = StudentBlog.find(blog_id)
      
          spark_post_content = PostContent.create(
            spark_post: post,
            pseudonym: blog,
            title: blog.title,
            content_type: 'Blog'
          )
      
          if spark_post_content.persisted?
            create_user_interaction(current_user.id, 'blog_post_count')
            render json: { status: true, data: { post_id: post.id, content_id: spark_post_content.id } }
          else
            raise ActiveRecord::Rollback # Rollback transaction if content creation fails
            render json: { status: false, message: 'Failed to create post content' }
          end
        end
      end
      

      def get_post_report_form
        @postId=params[:post_id]
        @report_options=PostReport.contents.keys
        render partial:"post_report", locals:{postId:@postId,report_options:@report_options} 
      end

      def add_post_report
        @post_id = params[:post_id]
        @report_reason = params[:report_reason]
        @post = Post.find(@post_id)
        
        existing_report = @post.spark_post_reports.find_by(user: current_user, content: @report_reason)
        
        if existing_report.nil?
          @report = @post.spark_post_reports.create(user: current_user, content: @report_reason)
          create_user_interaction(current_user.id,'report_count')
          render json: { status: true, id: @report.id }
        else
          render json: { status: false, message: 'You have already reported with same reason' }
        end
      end

      def is_user_banned(user_id)
        false
      end

      def create_user_interaction(user_id,count_column)
        d=Date.today
        user_interaction=PostUserInteraction.find_or_initialize_by(user_id:user_id,start_date:d.beginning_of_week.beginning_of_day.in_time_zone, end_date:d.end_of_week.end_of_day.in_time_zone)
        user_interaction.send("#{count_column}=", (user_interaction.send(count_column).to_i ||0 )+ 1)
        user_interaction.last_acted_at = Time.now
        user_interaction.save
      end

      def update_page_visit
        d=Date.today
        user_interaction=PostUserInteraction.find_or_initialize_by(user_id:current_user.id,start_date:d.beginning_of_week.beginning_of_day.in_time_zone, end_date:d.end_of_week.end_of_day.in_time_zone)
        user_interaction.page_visit_count = (user_interaction.page_visit_count || 0)+1
        user_interaction.last_visit_at = Time.now
        if user_interaction.save
          render json: { status: true, message: 'Updated' }
        else
          render json: { status: false, message: 'Failed Updating' }
        end
      end

      def get_user_notifications
        user_id = current_user.id
        last_date = DateTime.now - 10.days
        user_posts = Post.where(user_id: user_id)
        all_reactions =  Reaction.where(pseudonym_type: "Post", pseudonym_id: user_posts.pluck(:id)).where.not(user_id: user_id).where('created_at > ?',last_date)
        all_comments =  Comment.where(spark_post_id: user_posts.pluck(:id)).where.not(user_id: user_id).where('created_at > ?',last_date)
        all_likes = ActsAsVotable::Vote.where(votable_type: "Post", votable_id: user_posts.pluck(:id), vote_weight: 1).where.not(voter_id: user_id).where('created_at > ?',last_date)
        follows = SparklineFollow.where(followed_id: user_id).where('created_at > ?',last_date).map {|x| {action_type: "follow", user_id: x.follower_id, created_at: x.created_at}}

        reactions = all_reactions.map {|y| {post_id: y.pseudonym_id, action_type: "reaction", reaction: y.reaction, user_id: y.user_id,created_at: y.created_at}} 
        comments = all_comments.map {|y| {post_id: y.spark_post_id,action_type: "comment", comment: y.comment, user_id: y.user_id, created_at: y.created_at}}
        likes = all_likes.map {|y|{post_id: y.votable_id, action_type: "like", user_id: y.voter_id, created_at: y.created_at}}
        all_nots = reactions + comments + likes + follows
        user_names = {}
        User.where(id: all_nots.pluck(:user_id)).each do |x| 
          user_names[x.id] = {name: x.first_name, uuid: x.uuid}
        end
        all_nots.each do |x|
          x[:user_name] = user_names[x[:user_id]][:name]
          x[:user_uuid] = user_names[x[:user_id]][:uuid]
        end
        render partial:"post_notifications", locals:{notifications: all_nots}
      end

      private

      def authenticate_user
        if current_user.present?
        else
          redirect_to root_path
        end
      end

    end
  end  