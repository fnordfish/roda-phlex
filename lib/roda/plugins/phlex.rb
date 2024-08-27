# frozen_string_literal: true

class Roda
  module RodaPlugins
    # The Phlex Plugin provides functionality for integrating Phlex with Roda applications.
    #
    # ### Phlex Plugin Options
    #
    # - `:layout` (+::Phlex::SGML+): Specifies the layout class to be used for rendering
    #   views. This class should be a Phlex layout class that defines how the
    #   views are structured and rendered.
    # - `:layout_opts` (+Object+): Options that are passed to the layout
    #   class when it is instantiated. These options can be used to customize
    #   the behavior of the layout. Usually, this is a +Hash+.
    # - `:layout_handler` (+#call+): A custom handler for creating layout
    #   instances. This proc receives three arguments: the layout class, the
    #   layout options, and the object to be rendered. By default, it uses the
    #   `DEFAULT_LAYOUT_HANDLER`, which instantiates the layout class with the
    #   provided object and options as keyword arguments.
    # - `:delegate`: Define if or which methods should be delegated to the Roda app:
    #   - `true` (default): Create a single `app` method that delegates to the Roda app.
    #   - `false`: Do not create any delegate methods.
    #   - `:all`: Delegate all methods the Roda app responds to, to it. Be careful with this option.
    #             It can lead to unexpected behavior if the Roda app has methods that conflict with Phlex methods.
    #   - `Symbol`, `String`, `Array`: Delegate only the specified methods to the Roda app.
    module Phlex
      Undefined = Object.new
      private_constant :Undefined

      Error = Class.new(StandardError)

      # Custom TypeError class for Phlex errors.
      class TypeError < Error
        MAX_SIZE = 32

        # Initializes a TypeError instance.
        # @param obj [Object] The object that caused the error.
        def initialize(obj)
          content = obj.inspect
          content = content[0, MAX_SIZE] + "…" if content.size > MAX_SIZE
          super("Expected a Phlex instance, received #{content}")
        end
      end

      # The default layout handler for creating layout instances.
      # Expects layout options to be a +Hash+ when provided.
      DEFAULT_LAYOUT_HANDLER = proc do |layout, layout_opts, obj|
        layout_opts ? layout.new(obj, **layout_opts) : layout.new(obj)
      end

      # Configures the Phlex plugin for the Roda application.
      # @param app [Roda] The Roda application.
      # @param opts [Hash] The options for configuring the Phlex plugin.
      def self.configure(app, opts = OPTS)
        delegate = opts.key?(:delegate) ? opts.delete(:delegate) : true
        app.opts[:phlex] = opts
        app.opts[:phlex][:layout_handler] ||= DEFAULT_LAYOUT_HANDLER

        if delegate
          overrides = Module.new do
            def app
              @_view_context
            end

            case delegate
            when :all
              def method_missing(name, ...)
                if app.respond_to?(name)
                  app.send(name, ...)
                else
                  super
                end
              end

              def respond_to_missing?(name, include_private = false)
                app.respond_to?(name) || super
              end

            when Symbol, String, Array
              Array(delegate).each do |delegate|
                class_eval <<~RUBY, __FILE__, __LINE__ + 1
                  def #{delegate}(...)
                    app.#{delegate}(...)
                  end
                RUBY
              end
            end
          end

          ::Phlex::SGML.include(overrides)
        end
      end

      module InstanceMethods
        # Retrieves or sets the layout.
        # @param layout [Phlex::SGML, Undefined, nil] The layout to be set.
        # @return [Phlex::SGML, nil] The current layout or nil if not set.
        def phlex_layout(layout = Undefined)
          case layout
          when Undefined
            opts.dig(:phlex, :layout)
          when nil
            opts[:phlex].delete(:layout)
            opts[:phlex].delete(:layout_opts)
          when ::Phlex::SGML
            opts[:phlex][:layout] = layout
          else
            raise TypeError.new(layout)
          end
        end

        # Retrieves or sets the layout options.
        # @param layout_opts [Undefined, nil] The layout options to be set.
        # @return [Object, nil] The current layout options or nil if not set.
        def phlex_layout_opts(layout_opts = Undefined)
          case layout_opts
          when Undefined
            opts.dig(:phlex, :layout_opts)
          when nil
            opts[:phlex].delete(:layout_opts)
          else
            opts[:phlex][:layout_opts] = layout_opts
          end
        end

        # Retrieves or sets the layout handler.
        # @param handler [#call, Undefined, nil] The layout handler to be set.
        # @return [#call, nil] The current layout handler or nil if not set.
        def phlex_layout_handler(handler = Undefined)
          case handler
          when Undefined
            opts.dig(:phlex, :layout_handler)
          when nil
            opts[:phlex].delete(:layout_handler)
          else
            opts[:phlex][:layout_handler] = handler
          end
        end

        # Renders a Phlex object.
        # @param obj [Phlex::SGML] The Phlex object to be rendered.
        # @param content_type [String, nil] The content type of the response.
        # @param stream [Boolean] Whether to stream the response or not.
        def phlex(obj, content_type: nil, stream: false)
          raise TypeError.new(obj) unless obj.is_a?(::Phlex::SGML)

          content_type ||= "image/svg+xml" if obj.is_a?(::Phlex::SVG)
          response["Content-Type"] = content_type if content_type

          phlex_opts = opts[:phlex]
          renderer = if (layout = phlex_opts[:layout])
            phlex_layout_handler.call(layout, phlex_opts[:layout_opts], obj)
          else
            obj
          end

          if stream
            self.stream do |out|
              renderer.call(out, view_context: self)
            end
          else
            renderer.call(view_context: self)
          end
        end
      end
    end

    register_plugin :phlex, Phlex
  end
end
