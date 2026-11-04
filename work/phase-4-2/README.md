# ルーティングをTDDで実装する
## Router の実装

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

  def get(pattern, &block)
    @routes << Route.new('GET', pattern, block)
  end

  def post(pattern, &block)
    @routes << Route.new('POST', pattern, block)
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

## テストコード

```ruby
require_relative 'test_helper'
require_relative '../router'

class RouterTest < Minitest::Test
  def test_get_root_returns_200
    router = Router.new

    router.get '/' do |_|
      [200, {}, ['OK']]
    end

    status, _, body = router.call(env_for('/'))

    assert_equal 200, status
    assert_equal ['OK'], body
  end

  def test_get_users
    router = Router.new

    router.get '/' do |_req|
      [200, {}, ['root']]
    end

    router.get '/users' do |_req|
      [200, {}, ['users']]
    end

    _, _, body = router.call(env_for('/users'))

    assert_equal ['users'], body

    _, _, body = router.call(env_for('/'))

    assert_equal ['root'], body
  end

  def test_post_users
    router = Router.new

    router.post '/users' do |_req|
      [200, {}, ['created']]
    end

    router.get '/users' do |_req|
      [200, {}, ['users']]
    end

    _, _, body = router.call(env_for('/users', method: 'POST'))

    assert_equal ['created'], body

    _, _, body = router.call(env_for('/users'))

    assert_equal ['users'], body
  end

  def test_returns_404_when_not_found
    router = Router.new

    status, _, _ = router.call(env_for('/unknown'))

    assert_equal 404, status
  end

  def test_dynamic_route
    router = Router.new

    router.get '/users/:id' do |req|
      id = req.path_params['id']
      [200, {}, [id]]
    end

    router.get '/users/:hoge/foo/bar' do |req|
      id = req.path_params['hoge']
      [200, {}, [id]]
    end

    router.get '/users/:id/foo/:name' do |req|
      id = req.path_params['id']
      [200, {}, [id]]
    end

    status, _, body = router.call(env_for('/users/42'))

    assert_equal ['42'], body

    status, _, body = router.call(env_for('/users/42/foo/alice'))

    assert_equal ['42'], body
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

## 設計メモ

### テストから設計がどう決まったか

どのような属性とメソッドを持ったクラスが必要かが決まった

### 最初に書いたテストは何を固定したか

パス、HTTPメソッド、レスポンス

### リファクタリングで何を改善したか

@routes をハッシュから配列に変更することでコードをシンプルにした
