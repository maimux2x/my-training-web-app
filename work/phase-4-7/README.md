# 共通処理（before_action / Middleware的仕組み）をTDDで導入する

## テストコード

```ruby
require_relative 'test_helper'
require_relative '../router'
require_relative '../app/controllers/authors_controller'
require_relative '../app/controllers/publishers_controller'

class CallbackTest < Minitest::Test
  def setup
    @controller = AuthorsController.new(env_for('/authors'))
  end

  def teardown
    # TODO: コールバックをテストする際は、テスト用に使い捨てのコントローラを定義する

    AuthorsController.clear_callbacks
    PublishersController.clear_callbacks
  end

  def test_before_action_runs_before_action_method
    called = []

    AuthorsController.before_action do
      called << 'before'
    end

    @controller.dispatch(:index)

    assert_equal ['before'], called
  end

  def test_before_action_runs_before_action_method_via_router
    called = []

    AuthorsController.before_action do
      called << 'before'
    end

    router = Router.new

    router.get '/index', to: 'authors#index'

    _, _, res = router.call(env_for('/index'))

    assert_equal ['index'], res
    assert_equal ['before'], called
  end

  def test_multiple_before_actions_run_in_order
    calls = []

    AuthorsController.before_action { calls << 1 }
    AuthorsController.before_action { calls << 2 }

    @controller.dispatch(:index)

    assert_equal [1, 2], calls
  end

  def test_before_action_only_applies_to_specific_action
    calls = []

    AuthorsController.before_action(only: [:index]) do
      calls << 'before'
    end

    @controller.dispatch(:index)

    assert_equal ['before'], calls

    controller = AuthorsController.new(env_for('/authors'))

    calls.clear

    controller.dispatch(:show)

    assert_equal [], calls
  end

  def test_before_action_skip_specific_action
    calls = []

    AuthorsController.before_action(except: [:show]) do
      calls << 'before'
    end

    @controller.dispatch(:show)

    assert_equal [], calls

    controller = AuthorsController.new(env_for('/authors'))

    calls.clear

    controller.dispatch(:index)

    assert_equal ['before'], calls
  end

  def test_before_action_can_halt_execution
    AuthorsController.before_action do
      render_text 'blocked'
    end

    calls = []

    AuthorsController.before_action do
      calls << 'before'
    end

    response = @controller.dispatch(:index)

    assert_equal ['blocked'], response[2]
    assert_equal [], calls
  end

  def test_before_action_can_reference_method
    AuthorsController.before_action(:before, only: [:foo])

    response = @controller.dispatch(:foo)

    assert_equal ['before'], response[2]
  end

  def test_callbacks_fire_when_inheriting_from_other_controller
    controller = PublishersController.new(env_for('/publishers'))
    calls = []

    AuthorsController.before_action do
      calls << 'author'
    end

    PublishersController.before_action do
      calls << 'publisher'
    end

    controller.dispatch(:index)

    assert_equal %w[author publisher], calls
  end

  def test_child_controllers_before_action_does_not_fire_when_halt_execution_with_parent_controller
    controller = PublishersController.new(env_for('/publishers'))
    calls = []

    AuthorsController.before_action do
      render_text 'blocked'
    end

    PublishersController.before_action do
      calls << 'publisher'
    end

    response = controller.dispatch(:index)

    assert_equal ['blocked'], response[2]
    assert_equal [], calls
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

```ruby
require_relative '../../router'

require 'erb'

class ControllerBase
  def self.action(method)
    ->(req) {
      new(req).dispatch(method)
    }
  end

  def self.before_action(method = nil, only: nil, except: [], &block)
    callbacks << [method, only, except, block]
  end

  def self.callbacks
    @callbacks ||= []
  end

  def self.clear_callbacks
    callbacks.clear
  end

  def self.all_callbacks
    ancestors.select {|klass|
      klass.respond_to?(:callbacks)
    }.reverse.flat_map(&:callbacks)
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
    self.class.all_callbacks.each do |(method, only, except, block)|
      break if @res
      next if except.include?(action)
      next unless only.nil? || only.include?(action)

      if method
        send method
      else
        instance_exec(&block)
      end
    end

    public_send action unless @res

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

## 設計メモ

### before_actionは何を解決するか

アクションの実行前に必ず実行させたい処理を個別に書かなくて済む。

### なぜControllerに入れるのか

コントローラがアクションを実行するから。

### Middlewareとの違い

Rackミドルウェアはリクエストがメインのアプリに到達する前後に処理を実行できる。
コールバックはアプリのコントローラでアクションが実行される前後（※この課題では前のみ実装）に処理を実行できる。

### 処理の流れはどう設計したか

テストで期待する振る舞いを決めながら、実装で詰まった部分の課題の分解や考慮漏れがないかを Claude Code に相談しながら進めた。
