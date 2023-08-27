Rails.application.routes.draw do
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  root "home#index"
  get '/timeline', to: 'timeline/feed#index'
  get '/timeline/posts', to: 'timeline/feed#list_posts'
  get '/timeline/get_post_stats', to: 'timeline/feed#get_post_stats'
  get '/timeline/get_user_posts_stats', to: 'timeline/feed#get_user_posts_stats'
  post '/timeline/add_reaction', to: 'timeline/feed#add_reaction'
  post '/timeline/add_comment', to: 'timeline/feed#add_comment'
  get '/timeline/get_post', to: 'timeline/feed#get_post'
  post '/timeline/create_image_post', to: 'timeline/feed#create_image_post'
  post '/timeline/create_video_post', to: 'timeline/feed#create_video_post'
  post '/timeline/create_blog_post', to: 'timeline/feed#create_blog_post'
  post '/timeline/add_post_report', to: 'timeline/feed#add_post_report'
  get '/timeline/get_post_report_form', to: 'timeline/feed#get_post_report_form'
  post '/timeline/create_post_violation_report', to: 'timeline/feed#create_post_violation_report'
  post '/timeline/update_page_visit', to: 'timeline/feed#update_page_visit'
  get '/timeline/get_user_notifications', to: 'timeline/feed#get_user_notifications'

  get '/timeline/profile/:id', to: 'timeline/profile#index'
  get '/timeline/post/:id', to: 'timeline/profile#post'
  get '/timeline/get_public_post_stats', to: 'timeline/profile#get_public_post_stats'
  post '/timeline/profile/follow_action', to: 'timeline/profile#follow_action'
  
end
