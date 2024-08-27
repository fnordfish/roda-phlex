# roda-phlex

A [Roda](https://github.com/jeremyevans/roda) plugin that adds some convenience rendering [Phlex](https://github.com/phlex-ruby/phlex) views.  
Especially accessing application methods from the view.

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add roda-phlex
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install roda-phlex
```

## Configuration

`plugin :phlex` takes the following options:

- `:layout` (`Phlex::SGML`): Specifies the layout class to be used for rendering
  views. This class should be a Phlex layout class that defines how the
  views are structured and rendered.
- `:layout_opts` (`Object`): Options that are passed to the layout
  class when it is instantiated. These options can be used to customize
  the behavior of the layout. Usually, this is a `Hash`.
- `:layout_handler` (`#call`): A custom handler for creating layout
  instances. This proc receives three arguments: the layout class, the
  layout options, and the object to be rendered. By default, it uses the
  `layout.new(obj, **layout_opts)`, which instantiates the layout class with the
  provided view object and options as keyword arguments.
- `:delegate`: Define if or which methods should be delegated to the Roda app:
  - `true` (default): Create a single `app` method that delegates to the Roda app.
  - `false`: Do not create any delegate methods.
  - `:all`: Delegate all methods the Roda app responds to, to it. Be careful with this option.
            It can lead to unexpected behavior if the Roda app has methods that conflict with Phlex methods.
  - `Symbol`, `String`, `Array`: Delegate only the specified methods to the Roda app.

## Usage

Add the plugin to the Roda application:

```ruby
plugin :phlex
```

Use the `phlex` method in the view to render a Phlex view:

```ruby
route do |r|
  r.root do
    phlex MyView.new
  end
end
```

You can use all application methods in the view:

```ruby
plugin :sinatra_helpers
plugin :phlex, delegate: [:url]

class MyView < Phlex::View
  def view_template
    h1 { 'Phlex / Roda request params integration' }
    p {
      a(href: url("/path", true)) { "link" }
    }
    pre { app.request.params.inspect }
  end
end
```

You can also pass an alternative content type (automatically sets `image/svg+xml` for a `Phlex::SVG` instance):

```ruby
route do |r|
  r.get '/foo' do
    phlex MyView.new, content_type: "application/xml"
  end
end
```

## Streaming

Streaming a Phlex view can be enabled by passing `stream: true` which will cause Phlex to automatically write to the response after the closing `</head>` and buffer the remaining content.  
The Roda `:stream` plugin must be enabled for this to work.

```ruby
plugin :streaming

get '/foo' do
  phlex MyView.new, stream: true
end
```

You can also manually flush the contents of the buffer at any point using Phlex's `#flush` method:

```ruby
class Layout < Phlex::HTML
  def template(&block)
    doctype
    html {
      head {
        # All the usual stuff: links to external stylesheets and JavaScript etc.
      }
      # Phlex will automatically flush to the response at this point which will
      # benefit all pages that opt in to streaming.
      body {
        # Standard site header and navigation.
        render Header.new

        yield_content(&block)
      }
    }
  end
end

class MyView < Phlex::HTML
  def template
    render Layout.new {
      # Knowing that this page can take a while to generate we can choose to
      # flush here so the browser can render the site header while downloading
      # the rest of the page - which should help minimise the First Contentful
      # Paint metric.
      flush

      # The rest of the big long page...
    }
  end
end
```

## Reconfiguring in a route

```ruby
# Define a default layout and layout options for the whole application
plugin :phlex, layout: MyLayout, layout_opts: { title: +"My App" }
route do |r|
  r.on "posts" do
    # redefine the layout and layout options for this route tree
    phlex_layout MyPostLayout
    phlex_layout_opts[:title] << " - Posts"

    r.get 'new' do
      # Redefine the layout and layout options for this route
      phlex_layout_opts[:title] = "Create new post"
      phlex MyView.new
    end
  end
end
```

## Contributing

Bug reports and pull requests are welcome on GitHub at <https://github.com/fnordfish/roda-phlex>. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/fnordfish/roda-phlex/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Roda::Phlex project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/fnordfish/roda-phlex/blob/main/CODE_OF_CONDUCT.md).

## Acknowledgements

This gem is based on [phlex-sinatra](https://github.com/benpickles/phlex-sinatra), and extended by the layout handling features in [RomanTurner's gist](https://gist.github.com/RomanTurner/0ce0b8792e4149d152d2af2224cb6407)
