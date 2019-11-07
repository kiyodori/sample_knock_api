# Knockを用いたJWT認証のRails APIサーバー

今回は上記のサンプルとして、認証されたユーザーだけがブログの投稿を閲覧できるシステムを作ってみます。

### APIモードのアプリケーションを作成する

Rails5のAPIモードのアプリケーションを作成します。

```
$ bundle init
$ vim Gemfile
```

GemfileにRails5 `gem 'rails', '5.0.0.1'` を追記してインストールします。

```
$ bundle install --path vendor/bundle
```

Rails APIモードのアプリケーションを作成します。

```
$ bundle exec rails new sample_knock_api --api
$ cd sample_knock_api
```

## 事前準備

### model
#### Post model を用意します

```
$ bin/rails g model Post title:string body:text --no-test-framework
```

```app/models/post.rb
class Post < ApplicationRecord
  validates :body, presence: true
  validates :title, presence: true
end
```

#### User model を用意します
`has_secure_password`は、Bcryptで暗号化したものをセットしたり認証する機能を提供するメソッドです。これを使うために`password_digest`カラムを用意します。

```
$ bin/rails g model user password_digest:string name:string email:string --no-test-framework
```

```app/models/user.rb
class User < ApplicationRecord
  has_secure_password

  validates :name, presence: true
  validates :email, presence: true
end
```

マイグレーション。

```
$ bin/rails db:create db:migrate
```

#### 初期データを突っ込みます
Gemfileに`gem 'ffaker'`を追加して、`bundle install --path vendor/bundle`します。
`ffaker`はテストデータを作成するためのGemです。Postのデータを適当に作成します。

```db/seeds.rb
require 'ffaker'

Post.destroy_all
User.destroy_all

User.create!({
  name: '田中 太郎',
  email: 'test@user.com',
  password: 'test123',
  password_confirmation: 'test123'
})

10.times do
  Post.create!(
    title: FFaker::Lorem.sentence,
    body: FFaker::Lorem.paragraphs.join(' ')
  )
end
```

初期データを投入します。

```
$ bin/rails db:seed
```

データベースに接続してデータが作成されているか確認します。

```
$ bin/rails db
# テーブル一覧の確認
sqlite> .tables
# テーブル定義の確認
sqlite> .schema users
# データ確認
sqlite> SELECT * FROM posts;
# 終了する
sqlite> .quit
```

## JSON APIサーバーにする
これでModelとサンプルデータの作成が完了したので、次にControllers, Resources, Routingの設定を行っていきます。

```
$ bin/rails g controller Posts
```

Gemfileに`gem 'jsonapi-resources'`して`JSONAPI::Resources`を導入します。`JSONAPI::Resources`はJSON APIサーバーを開発するのに便利な機能を提供してくれるGemです。

```app/controllers/posts_controller.rb
class PostsController < ApplicationController
  include JSONAPI::ActsAsResourceController
end
```

`Posts`リソースを作成します。

```
$ bin/rails generate jsonapi:resource posts
```

```app/resources/post_resource.rb
class PostResource < JSONAPI::Resource
  immutable
  attributes :title, :body
end
```

routingの設定。

```config/routes.rb
...
jsonapi_resources :posts
...
```

## 認証を行う
さて、ここからがJWT認証を行っていきます。
Gemfileに`gem 'knock'`を追記して`bundle install`します。

```
# knockをインストールする
$ bin/rails generate knock:install

create  config/initializers/knock.rb

# userがサインインできるようにする。外部サービスを使用する場合はここは不要
$ bin/rails generate knock:token_controller user

create  app/controllers/user_token_controller.rb
route  post 'user_token' => 'user_token#create'
```

`application_controller`に`Knock::Authenticable`モジュールを追加します。

```app/controlers/application_controller.rb
class ApplicationController < ActionController::API
  include Knock::Authenticable
end
```

`posts_contorller`に`before_action :authenticate_user`を追加することで、Postリソースを保護します。

```app/controllers/posts_controller.rb
class PostsController < ApplicationController
  include JSONAPI::ActsAsResourceController
  before_action :authenticate_user # この一行を追加
end
```

さて、これで完成したので試してみます。
まずユーザーの認証を行います。ユーザーのemailとpasswordが正しいとトークンが返ってくるので、そのトークンを用いてpostデータをリクエストすると、postデータが返ってきます。

```
# サーバーを起動
$ bin/rails s

# 別ターミナルから行う
# ユーザーの認証を行う
$ curl -X "POST" "http://localhost:3000/user_token" -H "Content-Type: application/json" -d $'{"auth": {"email": "test@user.com", "password": "test123"}}'

{"jwt":"eyJ0eXAiO..."}

# postデータをリクエストする
$ curl -X "GET" "http://localhost:3000/posts" -H "Authorization: Bearer eyJ0eXAiO..." -H "Content-Type: application/json"

{"data":[{"id":"1","type":"posts","links":{"self":"http://localhost:3000/posts/1"},"attributes":{"title":"Quos sed ...","body":"Eligendi porro ..."}},{"id":"2","type":"posts","links":{"self":"http://localhost:3000/posts/2"},"attributes":{"title":"Nisi autem ...","body":"Minima quod ..."}}, ...
```

