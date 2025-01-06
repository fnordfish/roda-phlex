# frozen_string_literal: true

require_relative "views"

module TestAppHelper
  module_function

  def app
    build_test_app(@test_app_plugins)
  end

  def build_test_app(test_app_plugins = {})
    Class.new(Roda) do
      test_app_plugins.each do |name, opts|
        if opts.empty?
          plugin name
        else
          plugin name, opts
        end
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

        r.get "application-link" do
          phlex ApplicationLinkView.new(r.params["full"])
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
                set_phlex_layout_opts title: title
              end
              phlex FooView.new, content_type: "text/html"
            end
          end

          r.get "nil" do
            set_phlex_layout nil
            phlex FooView.new
          end

          r.get "false" do
            set_phlex_layout false
            phlex FooView.new
          end

          r.get "phlex_layout_override" do
            set_phlex_layout AlternativeLayout
            set_phlex_layout_opts title: "phlex_layout_override"
            phlex FooView.new("content")
          end

          r.on "merge_opts_route_override" do
            # Directly mutating the plugin config is not recommended.
            # Use `set_phlex_layout` and `set_phlex_layout_opts` instead.
            opts[:phlex][:layout] = AlternativeLayout
            opts[:phlex][:layout_opts] = {title: "route-title"}

            r.get do
              if (title = r.params["title"])
                phlex_layout_opts[:title] = title
              end
              phlex FooView.new, content_type: "text/html"
            end
          end

          r.on "mutate_opts" do
            r.get "unsafe" do
              if (title = r.params["title"])
                # DON'T do this. This will mutate the plugin config and carry over to the next request.
                phlex_layout_opts[:title].prepend title, " - "
              end
              phlex FooView.new, content_type: "text/html"
            end

            r.get "safer" do
              if (title = r.params["title"])
                # Mutating the shallow copy of layout options
                phlex_layout_opts[:title] = phlex_layout_opts[:title].dup.prepend title, " - "
              end
              phlex FooView.new, content_type: "text/html"
            end

            r.get "safe" do
              if (title = r.params["title"])
                # Setting a new layout options hash
                set_phlex_layout_opts phlex_layout_opts.merge(title: "#{title} - #{phlex_layout_opts[:title]}")
              end
              phlex FooView.new, content_type: "text/html"
            end
          end
        end

        r.on "layout_handler" do
          set_phlex_layout AlternativeLayout
          set_phlex_layout_handler ->(layout, _opts, obj) {
            layout.new(obj, title: "phlex_layout_handler override")
          }

          r.is do
            phlex FooView.new
          end

          r.get "reset_via_nil" do
            set_phlex_layout_handler nil
            phlex FooView.new
          end

          r.get "reset_via_default" do
            set_phlex_layout_handler :default
            phlex FooView.new
          end
        end
      end
    end.app
  end
end
