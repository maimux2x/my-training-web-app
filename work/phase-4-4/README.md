# render / redirect をTDDで実装する
## テストコード

```ruby
require_relative 'test_helper'
require_relative '../router'
require_relative '../app/controllers/pages_controller'
require_relative '../app/controllers/users_controller'
require_relative '../app/controllers/double_render_controller'
require_relative '../app/controllers/empty_controller'

class RenderTest < Minitest::Test
  def test_action_can_render_text
    router = Router.new

    router.get '/hello', to: 'pages#hello'

    status, headers, body = router.call(env_for('/hello'))

    assert_equal 200,          status
    assert_equal 'text/plain', headers['content-type']
    assert_equal ['Hello'],    body
  end

  def test_action_does_not_need_to_return_rack_response_directly
    controller = PagesController.new(MyRequest.new(env_for('/hello')))
    response   = controller.dispatch(:hello)

    assert_equal 200,          response[0]
    assert_equal 'text/plain', response[1]['content-type']
    assert_equal ['Hello'],    response[2]
  end

  def test_action_can_render_html
    router = Router.new

    router.get '/html', to: 'pages#html'

    status, headers, body = router.call(env_for('/html'))

    assert_equal 200,                status
    assert_equal 'text/html',        headers['content-type']
    assert_equal ['<h1>Hello</h1>'], body
  end

  def test_render_text_can_accept_status
    router = Router.new

    router.get '/not_found', to: 'pages#not_found'

    status, headers, body = router.call(env_for('/not_found'))

    assert_equal 404,           status
    assert_equal 'text/plain',  headers['content-type']
    assert_equal ['Not Found'], body
  end

  def test_action_can_redirect
    router = Router.new
    router.post '/users', to: 'users#create'

    status, headers, body = router.call(env_for('/users', method: 'POST'))

    assert_equal 302, status
    assert_equal '/users', headers['location']
    assert_equal [], body
  end

  def test_redirect_to_can_accept_status
    controller = UsersController.new(MyRequest.new(env_for('/users')))
    response   = controller.dispatch(:moved)

    assert_equal 301,          response[0]
    assert_equal '/new_users', response[1]['location']
  end

  def test_raises_error_when_render_called_twice
    controller = DoubleRenderController.new(MyRequest.new(env_for('/double')))

    assert_raises RuntimeError do
      controller.dispatch :index
    end
  end

  def test_raises_error_when_nothing_rendered
    controller = EmptyController.new(MyRequest.new(env_for('/empty')))

    assert_raises RuntimeError do
      controller.dispatch :index
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
### ControllerBase

```ruby
require_relative '../../router'

class ControllerBase
  def self.action(method)
    ->(req) {
      new(req).send(method)
    }
  end

  def initialize(req)
    @req = req
    @res = nil
  end

  def render_text(text, status: 200)
    build_response status, {'content-type' => 'text/plain'}, [text]
  end

  def render_html(html, status: 200)
    build_response status, {'content-type' => 'text/html'}, [html]
  end

  def redirect_to(path, status: 302)
    build_response status, {'content-type' => 'text/plain', 'location' => path}, []
  end

  def dispatch(action)
    send(action)

    if @res.nil?
      raise RuntimeError
    else
      @res
    end
  end

  private

  def params
    @req.path_params
  end

  def build_response(status, header, body)
    if @res.nil?
      @res = [status, header, body]
    else
      raise RuntimeError
    end
  end
end
```

### サンプルコントローラ

#### PagesController

```ruby
require_relative 'controller_base'

class PagesController < ControllerBase
  def hello
    render_text 'Hello'
  end

  def html
    render_html '<h1>Hello</h1>'
  end

  def not_found
    render_text 'Not Found', status: 404
  end

  def create
    redirect_to '/hello'
  end
end
```

#### UsersController

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
    redirect_to '/users'
  end

  def moved
    redirect_to '/new_users', status: 301
  end
end
```

#### DoubleRenderController

```ruby
require_relative 'controller_base'

class DoubleRenderController < ControllerBase
  def index
    render_text 'A'
    render_text 'B'
  end
end
```

#### EmptyController

```ruby
require_relative 'controller_base'

class EmptyController < ControllerBase
  def index; end
end
```

## 設計メモ

### render は何を抽象化しているか

HTTP レスポンス


### redirect は HTTP 的に何をしているか

移動先をlocationヘッダーに保持して、レスポンスを返すこと

### Action から Rack 配列を直接返さない利点は何か

Rack 配列は共通の仕様であるため、実装の重複を避けることができる

### 何も render しない場合の仕様をどう決めたか

コントローラのアクションは何かしらの戻り値を返すことが期待される振る舞いであるため、例外を発生させるようにした

### テストによって設計がどう変わったか

分かりません。
