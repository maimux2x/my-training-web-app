# Request / Params をTDDで整理する

## テストコード

```ruby
require_relative 'test_helper'
require_relative '../router'
require_relative '../app/controllers/pages_controller'
require_relative '../app/controllers/users_controller'

require 'cgi'

class RequestParamsTest < Minitest::Test
  def test_controller_can_access_request
    router = Router.new

    router.get '/info', to: 'pages#info'

    status, _, body = router.call(env_for('/info'))

    assert_equal 200,     status
    assert_equal ['GET'], body
  end

  def test_controller_can_access_query_params
    router = Router.new

    router.get '/search', to: 'pages#search'

    status, _, body = router.call(env_for('/search?keyword=ruby'))

    assert_equal 200,      status
    assert_equal ['ruby'], body
  end

  def test_controller_can_access_path_params_from_params
    router = Router.new

    router.get '/users/:id', to: 'users#show'

    status, _, body = router.call(env_for('/users/42'))

    assert_equal 200,    status
    assert_equal ['42'], body
  end

  def test_params_contain_both_path_and_query_params
    router = Router.new

    router.get '/pages/:id', to: 'pages#show'

    status, _, body = router.call(env_for('/pages/42?page=3'))

    assert_equal 200,              status
    assert_equal ['id=42,page=3'], body
  end

  def test_path_and_query_keys_conflict
    router = Router.new

    router.get '/pages/:id', to: 'pages#conflict'

    status, _, body = router.call(env_for('/pages/42?id=3'))

    assert_equal 200,       status
    assert_equal ['id=42'], body
  end

  def test_controller_can_access_form_params
    router = Router.new

    router.post '/pages', to: 'pages#create'

    env = env_for('/pages', method: 'POST', params: { 'name' => 'Alice' })

    status, _, body = router.call(env)

    assert_equal 200,       status
    assert_equal ['Alice'], body
  end

  def test_request_exposes_path_and_method
    router = Router.new

    router.post '/inspect', to: 'pages#inspect'

    status, _, body = router.call(env_for('/inspect', method: 'POST'))

    assert_equal 200,               status
    assert_equal ['/inspect|POST'], body
  end

  def test_return_nil_when_key_does_not_exist
    router = Router.new

    router.get '/pages/:id', to: 'pages#show'

    status, _, body = router.call(env_for('/pages/42'))

    assert_equal 200,             status
    assert_equal ['id=42,page='], body
  end

  def test_params_are_accessed_with_string_keys
    router = Router.new

    router.get '/search', to: 'users#search'

    _, _, body = router.call(env_for('/search?keyword=ruby'))

    assert_equal ['ruby|'], body
  end

  private

  def env_for(path, method: 'GET', params: {})
    path, query = path.split('?')

    body = params.map {|k, v|
      "#{CGI.escape(k)}=#{CGI.escape(v)}"
    }.join('&')

    {
      'PATH_INFO'      => path,
      'REQUEST_METHOD' => method,
      'QUERY_STRING'   => query,
      'rack.input'     => StringIO.new(body)
    }
  end
end
```

## 実装コード

### ControllerBase

```ruby
require_relative '../../router'

require 'erb'

class ControllerBase
  def self.action(method)
    ->(req) {
      new(req).dispatch(method)
    }
  end

  def initialize(req)
    @request = req
    @res     = nil
  end

  attr_reader :request

  def render_text(text, status: 200)
    build_response status, {'content-type' => 'text/plain'}, [text]
  end

  def render_html(html, status: 200)
    build_response status, {'content-type' => 'text/html'}, [html]
  end

  def render_file(path)
    render_html read_view_file(path)
  end

  def render_view(path)
    context = ViewContext.new

    (instance_variables - %i[@request @res]).each do |name|
      context.instance_variable_set name, instance_variable_get(name)
    end

    render_html ERB.new(read_view_file("#{path}.erb"), trim_mode: '-').result(context._binding)
  end

  def redirect_to(path, status: 302)
    build_response status, {'location' => path}, []
  end

  def dispatch(action)
    public_send action

    raise 'nothing rendered' unless @res

    @res
  end

  private

  def params
    @request.params.merge(@request.path_params)
  end

  def build_response(status, header, body)
    raise 'double rendered' if @res

    @res = [status, header, body]
  end

  def read_view_file(path)
    File.read(File.join('app/views', path))
  end
end

class ViewContext
  include ERB::Util

  def _binding
    binding
  end
end
```

### Router

```ruby
require 'rack'

class Router
  class Route
    def initialize(method, pattern, block)
      @method       = method
      @pattern      = pattern
      @block        = block
      @path_params  = {}
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
    register_route 'GET', pattern, to, block
  end

  def post(pattern, to: nil, &block)
    register_route 'POST', pattern, to, block
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

  private

  def register_route(method, pattern, to, block)
    to = if to.instance_of?(String)
      klass, action = to.split('#', 2)

      Class.const_get("#{klass.split('_').map(&:capitalize).join}Controller").action(action)
    else
      to
    end

    @routes << Route.new(method, pattern, to || block)
  end
end

class MyRequest < Rack::Request
  def path_params = env['rack.path_params']
end
```


### サンプルController

#### UsersController

```ruby
require_relative 'controller_base'

class UsersController < ControllerBase
  def index
    render_text 'Users Index'
  end

  def show
    render_text params['id']
  end

  def create
    redirect_to '/users'
  end

  def moved
    redirect_to '/new_users', status: 301
  end

  def title
    @title = 'Users'

    render_view 'users/index'
  end

  def repeat
    @names = ['Alice', 'Bob']

    render_view 'users/repeat'
  end

  def search
    render_text "#{params['keyword']}|#{params[:keyword]}"
  end
end
```

#### PagesController

```ruby
require_relative 'controller_base'

class PagesController < ControllerBase
  def show
    render_text "id=#{params['id']},page=#{params['page']}"
  end

  def create
    render_text params['name']
  end

  def conflict
    render_text "id=#{params['id']}"
  end

  def home
    render_file 'pages/home.html'
  end

  def bye
    render_html '<h1>Bye!</h1>'
  end

  def hello
    render_view 'pages/hello'
  end

  def html
    render_html '<h1>Hello</h1>'
  end

  def info
    render_text request.request_method
  end

  def search
    render_text params['keyword']
  end

  def inspect
    render_text "#{request.path}|#{request.request_method}"
  end

  def not_found
    render_text 'Not Found', status: 404
  end
end
```

## 設計メモ

### request と params は何が違うか

答えられず。

### なぜ query / path / form を params にまとめたのか

扱いやすいから

### parameter の優先順位をどう決めたか

答えられず。

### いま独自 Request クラスを本格導入しない理由

分かりません。

### テストによって設計がどう変わったか

分かりません。
