Rails.application.routes.draw do
  post 'user_token' => 'user_token#create'
  jsonapi_resources :posts
end
