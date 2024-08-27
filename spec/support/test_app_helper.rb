# frozen_string_literal: true

require_relative "views"

module TestAppHelper
  module_function

  def build_test_app(test_app_plugins = {})
    Class.new(Roda) do
      test_app_plugins.each do |name, opts|
        plugin name, opts
      end

      route do |r|
        r.root do
          "root"
        end

        r.get "error" do
          obj = case r.params["type"]
          when "phlex-class"
            FooView
          when "string"
            FooView.call
          when "string-long"
            FooView.call(("a".."z").to_a.join(" "))
          end

          phlex obj
        end

        r.get "foo" do
          FooView.call
        end

        r.get "link" do
          phlex LinkView.new(r.params["full"])
        end

        r.get "more" do
          phlex MoreDetailsView.new
        end

        r.on "stream" do
          r.is do
            r.get do
              phlex StreamingView.new, stream: true
            end
          end

          r.get "explicit" do
            phlex ExplicitLayout::MyView.new, stream: true
          end
        end

        r.on "svg" do
          r.is do
            r.get do
              phlex SvgElem.new
            end
          end

          r.get "plain" do
            phlex SvgElem.new, content_type: "text/plain"
          end
        end

        r.get "xml" do
          phlex FooView.new, content_type: "application/xml"
        end

        r.on "layout" do
          r.is do
            r.get do
              if (title = r.params["title"])
                phlex_layout_opts title: title
              end
              phlex FooView.new, content_type: "text/html"
            end
          end

          r.get "none" do
            phlex_layout nil
            phlex FooView.new
          end

          r.on "route_override" do
            opts[:phlex][:layout] = HomepageLayout
            opts[:phlex][:layout_opts] = {title: "route-title"}

            r.get do
              if (title = r.params["title"])
                phlex_layout_opts[:title] = title
              end
              phlex FooView.new, content_type: "text/html"
            end
          end
        end
      end
    end.app
  end
end
