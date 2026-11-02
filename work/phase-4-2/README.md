# ルーティングをTDDで実装する
## Router の実装

```ruby
class Router
  def initialize
    @endpoints = []
  end

  def get(pattern, &block)
    @endpoints << ['GET', pattern, block]
  end

  def post(pattern, &block)
    @endpoints << ['POST', pattern, block]
  end

  def call(env)
    @endpoints.each do |(method, pattern, block)|
      next unless env['REQUEST_METHOD'] == method

      path    = env['PATH_INFO'].split('/')
      pattern = pattern.split('/')

      next unless path.size == pattern.size

      params = {}

      next unless pattern.zip(path).all? {|x, y|
        if x.start_with?(':')
          params[x.delete_prefix(':')] = y
          true
        else
          x == y
        end
      }

      return block.call(Request.new(params))
    end

    [404, {}, ['Not Found']]
  end
end

class Request
  def initialize(path_params)
    @path_params = path_params
  end

  attr_reader :path_params
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

エンドポイント、HTTPメソッド、レスポンス

### リファクタリングで何を改善したか

Routerクラスをハッシュで初期化していたのを配列に変更した
