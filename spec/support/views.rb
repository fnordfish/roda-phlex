# frozen_string_literal: true

class FooView < Phlex::HTML
  def initialize(text = "foo")
    @text = text
  end

  def view_template
    p { @text }
  end
end

class LinkView < Phlex::HTML
  def initialize(full)
    @full = full
  end

  def view_template
    a(href: url("/bar", @full)) { "link" }
  end
end

class MoreDetailsView < Phlex::HTML
  def view_template
    pre { app.request.params.inspect }
  end
end

class StreamingView < Phlex::HTML
  def view_template
    html {
      head {
        title { "Streaming" }
      }
      body {
        p { 1 }
        flush # Internal private Phlex method.
        p { 2 }
      }
    }
  end
end

class SvgElem < Phlex::SVG
  def view_template
    svg { rect(width: 100, height: 100) }
  end
end

class HomepageLayout < Phlex::HTML
  attr_accessor :current_head

  class Empty < Phlex::HTML
    def view_template
      ""
    end
  end

  def initialize(component, title: "default-title")
    @title = title
    @component = component || Empty.new
  end

  def view_template
    html do
      head do
        meta(charset: "UTF-8")
        meta("http-equiv" => "UTF-8", "content" => "IE=edge")
        meta(
          name: "viewport",
          content: "width=device-width, initial-scale=1.0"
        )

        title { @title }
      end

      body { render @component }
    end
  end
end

module ExplicitLayout
  class Layout < Phlex::HTML
    def view_template(&block)
      doctype
      html {
        head {
          # All the usual stuff: links to external stylesheets and JavaScript etc.
        }
        # Phlex will automatically flush to the response at this point which will
        # benefit all pages that opt in to streaming.
        body {
          plain "Layout Start"
          yield_content(&block)
          plain "Layout End"
        }
      }
    end
  end

  class MyView < Phlex::HTML
    def view_template
      render Layout.new {
        # Knowing that this page can take a while to generate we can choose to
        # flush here so the browser can render the site header while downloading
        # the rest of the page - which should help minimise the First Contentful
        # Paint metric.
        flush

        p { "View Data" }
      }
    end
  end
end
