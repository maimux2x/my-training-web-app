# Controller / Action 構造をTDDで実装する
## テストコード

```ruby
require_relative 'test_helper'
require_relative '../router'
require_relative '../app/controllers/users_controller'
require_relative '../app/controllers/posts_controller'

class RouterToControllerTest < Minitest::Test
  def test_routes_to_controller_action
    router = Router.new

    router.get '/users', to: UsersController.action(:index)
    router.get '/posts', to: PostsController.action(:index)

    status, _, body = router.call(env_for('/users'))

    assert_equal 200, status
    assert_equal ['Users Index'], body

    status, _, body = router.call(env_for('/posts'))

    assert_equal 200, status
    assert_equal ['Posts Index'], body
  end

  def test_routes_to_different_actions_in_same_controller
    router = Router.new

    router.get '/users', to: UsersController.action(:index)
    router.post '/users/create', to: UsersController.action(:create)

    status, _, body = router.call(env_for('/users'))

    assert_equal 200, status
    assert_equal ['Users Index'], body

    status, _, body = router.call(env_for('/users/create', method: 'POST'))

    assert_equal 200, status
    assert_equal ['Users Create'], body
  end

  def test_routes_with_controller_action_string
    router = Router.new

    router.get '/users', to: 'users#index'
    router.post '/users/create', to: 'users#create'

    status, _, body = router.call(env_for('/users'))

    assert_equal 200, status
    assert_equal ['Users Index'], body

    status, _, body = router.call(env_for('/users/create', method: 'POST'))

    assert_equal 200, status
    assert_equal ['Users Create'], body
  end

  def test_controller_can_access_params
    router = Router.new

    router.get '/users/:id', to: 'users#show'

    status, _, body = router.call(env_for('/users/42'))

    assert_equal 200, status
    assert_equal ['42'], body
  end

  def test_unknown_controller_and_action
    router = Router.new

    assert_raises NameError do
      router.get '/books', to: 'books#index'
    end

    assert_raises NoMethodError do
      router.get '/users', to: 'users#foo'
      router.call(env_for('/users'))
    end
  end

  private

  def env_for(path, method: 'GET')
    {
      'PATH_INFO'       => path,
      'REQUEST_METHOD'  => method
    }
  end
end
```

## 実装コード
### Router

```ruby
require 'rack'

class Router
  class Route
    def initialize(method, pattern, block)
      @method      = method
      @pattern     = pattern
      @block       = block
      @path_params = {}
    end

    attr_reader :block, :path_params

    def match?(method, path)
      path_params.clear

      return false unless @method == method

      pattern_parts = @pattern.split('/')
      path_parts    = path.split('/')

      return false unless pattern_parts.size == path_parts.size

      pattern_parts.zip(path_parts).all? {|x, y|
        if x.start_with?(':')
          path_params[x.delete_prefix(':')] = y
          true
        else
          x == y
        end
      }
    end
  end

  def initialize
    @routes = []
  end

  def get(pattern, to: nil, &block)
    if to.instance_of?(String)
      klass, action = to.split('#', 2)
      to            = Class.const_get("#{klass.capitalize}Controller").action(action)
    end

    @routes << Route.new('GET', pattern, to || block)
  end

  def post(pattern, to: nil, &block)
    if to.instance_of?(String)
      klass, action = to.split('#', 2)
      to            = Class.const_get("#{klass.capitalize}Controller").action(action)
    end

    @routes << Route.new('POST', pattern, to || block)
  end

  def call(env)
    @routes.each do |route|
      if route.match?(env['REQUEST_METHOD'], env['PATH_INFO'])
        env['rack.path_params'] = route.path_params

        return route.block.call(MyRequest.new(env))
      end
    end

    [404, {}, ['Not Found']]
  end
end

class MyRequest < Rack::Request
  def path_params = env['rack.path_params']
end
```

### ControllerBase

```ruby
class ControllerBase
  def self.action(method)
    ->(req) {
      new(req).send(method)
    }
  end

  def initialize(req)
    @req = req
  end

  private

  def params
    @req.path_params
  end
end
```

### サンプル Controller

```ruby
require_relative 'controller_base'

class UsersController < ControllerBase
  def index
    [200, {}, ['Users Index']]
  end

  def show
    [200, {}, [params['id']]]
  end

  def create
    [200, {}, ['Users Create']]
  end
end
```

```ruby
require_relative 'controller_base'

class PostsController < ControllerBase
  def index
    [200, {}, ['Posts Index']]
  end

  def show
    [200, {}, [params['id']]]
  end

  def create
    [200, {}, ['Posts Create']]
  end
end
```

## 設計メモ
### Proc ではなく Controller が必要な理由

共通している処理と個別の処理とを分離して扱いやすくできるため

### Router と Controller の責務の違い

Router は経路を保持して、適切に繋ぐ役割
Controller は経路の目的地として結果を返す役割

### ControllerBase を導入した理由

個々の Controller で重複している処理をまとめるため

### その他

現在の Router は Controller の詳細を知りすぎている状態にはなっていないと判断している
dispatch インスタンスメソッドは現段階では不要と判断して、action クラスメソッドを使用している
存在しないコントローラやアクションが指定された場合は、Ruby の例外処理に任せている

### テストによって設計がどう決まったか

固定された振る舞いから逆算して、必要なステップを組み立てることができた
