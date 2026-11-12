# View / Template をTDDで導入する

## テストコード

```ruby
require_relative 'test_helper'
require_relative '../router'
require_relative '../app/controllers/pages_controller'
require_relative '../app/controllers/users_controller'
require_relative '../app/controllers/books_controller'

require 'erb'

class ViewTest < Minitest::Test
  def test_action_can_render_html_file
    write_view 'pages/home.html', '<h1>Home</h1>'

    router = Router.new

    router.get '/', to: 'pages#home'

    status, headers, body = router.call(env_for('/'))

    assert_equal 200,               status
    assert_equal 'text/html',       headers['content-type']
    assert_equal ['<h1>Home</h1>'], body
  end

  def test_action_can_render_erb_template
    write_view 'pages/hello.erb', "<h1>Hello <%= 'World' %></h1>"

    router = Router.new

    router.get '/hello', to: 'pages#hello'

    status, headers, body = router.call(env_for('/hello'))

    assert_equal 200,                      status
    assert_equal 'text/html',              headers['content-type']
    assert_equal ['<h1>Hello World</h1>'], body
  end

  def test_view_can_access_controller_instance_variables
    write_view 'users/index.erb', '<h1><%= h(@title) %></h1>'

    router = Router.new

    router.get '/users', to: 'users#title'

    _, _, body = router.call(env_for('/users'))

    assert_equal ['<h1>Users</h1>'], body
  end

  def test_view_can_render_collection_from_instance_variable
    write_view 'users/repeat.erb', <<~ERB
      <ul>
        <%- @names.each do |name| -%>
        <li><%= h(name) %></li>
        <%- end -%>
      </ul>
    ERB

    router = Router.new

    router.get '/users', to: 'users#repeat'

    _, _, body = router.call(env_for('/users'))

    assert_equal ["<ul>\n  <li>Alice</li>\n  <li>Bob</li>\n</ul>\n"], body
  end

  def test_render_view_resolves_template_path_under_views_directory
    write_view 'books/show.erb', '<h1>Book Detail</h1>'

    controller = BooksController.new(env_for('/books/1'))
    response   = controller.dispatch(:show)

    assert_equal ['<h1>Book Detail</h1>'], response[2]
  end

  def test_raises_error_when_template_is_missing
    controller = BooksController.new(env_for('/books'))

    assert_raises Errno::ENOENT do
      controller.dispatch(:index)
    end
  end

  private

  def env_for(path, method: 'GET')
    {
      'PATH_INFO'       => path,
      'REQUEST_METHOD'  => method
    }
  end

  def write_view(path, html)
    File.write("views/#{path}", html)
  end
end
```

## 実装コード

### ControllerBase

```ruby
require_relative '../../router'
require 'erb'

class ControllerBase
  include ERB::Util

  def self.action(method)
    ->(req) {
      new(req).dispatch(method)
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

  def render_file(path)
    render_html File.read("views/#{path}")
  end

  def render_view(view)
    render_html ERB.new(File.read("views/#{view}.erb"), trim_mode: '-').result(binding)
  end

  def redirect_to(path, status: 302)
    build_response status, {'content-type' => 'text/plain', 'location' => path}, []
  end

  def dispatch(action)
    public_send action

    raise 'nothing rendered' unless @res

    @res
  end

  private

  def params
    @req.path_params
  end

  def build_response(status, header, body)
    raise 'double rendered' if @res

    @res = [status, header, body]
  end
end
```

### サンプルコントローラ

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
end
```


```ruby
require_relative 'controller_base'

class BooksController < ControllerBase
  def index
    render_view 'books/missing'
  end

  def show
    render_view 'books/show'
  end
end
```

### サンプルViewファイル


#### views/users/index.erb

```
<h1><%= h(@title) %></h1>
```

#### views/users/repeat.erb

```
<ul>
  <%- @names.each do |name| -%>
  <li><%= h(name) %></li>
  <%- end -%>
</ul>
```

#### views/pages/hello.html

```html
<h1>Hello <%= 'World' %></h1>
```

#### views/pages/home.html

```html
<h1>Home</h1>
````

#### views/books/show.erb

```
<h1>Book Detail</h1>
```

## 設計メモ

### なぜ HTML を Controller に直接書かない方がよいのか

Rubyコードの中にHTMLが混ざって、可読性が悪い。かつ、HTMLの量が増えてくると修正もやりにくくなる。

### なぜ View から Controller のインスタンス変数を参照できるのか

binding によってERBテンプレートがコントローラのコンテキストで処理されるため。

### render_view は何を抽象化しているか

指定されたパスのファイルをERBテンプレートとして評価し、HTMLに変換した結果を返すこと

### テンプレートが存在しない場合の仕様をどう決めたか

テンプレートが存在しないことを明示するため、Errno::ENOENT が発生するままにした。

### layout が欲しくなる理由は何か

ヘッダーやフッターなどビューごとに共通しているHTMLを1箇所にまとめて書くことで、個々のビューで繰り返し書かなくて良くなるため
