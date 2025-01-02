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
    #     + `true` (default): Create a single `app` method that delegates to the Roda app.
    #     + `false`: Do not create any delegate methods.
    #     + `Array<Symbol,String>`: Delegate the named methods to the Roda app.
    # - `:delegate_on`: Class or module to define delegation methods on. Defaults to +::Phlex::SGML+.
    #    + Use this option to limit delegation methods to a application specific class or module
    #      (like "ApplicationView") to avoid polluting the global namespace.
    # - `:delegate_name`: The name of the method that delegates to the Roda app. Defaults to `"app"`.
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
      # Layout options are passed as keyword arguments to the layout class.
      #
      # @param layout [Class] The layout class to be instantiated.
      # @param layout_opts [Hash, nil] The layout options to be passed to the layout class.
      # @param obj [Phlex::SGML] The object to be rendered.
      DEFAULT_LAYOUT_HANDLER = proc do |layout, layout_opts, obj|
        layout_opts ? layout.new(obj, **layout_opts) : layout.new(obj)
      end

      # @!visibility private
      DELEGATE_ERROR_MESSAGE = "roda-phlex: :delegate is enabled, but :%s is to %s. Delegation will be disabled. Set :delegate to false to suppress this warning."
      private_constant :DELEGATE_ERROR_MESSAGE

      # Configures the Phlex plugin for the Roda application.
      # @param app [Roda] The Roda application.
      # @param opts [Hash] The options for configuring the Phlex plugin.
      def self.configure(app, opts = OPTS)
        delegate = opts.fetch(:delegate, true)
        if delegate
          delegate_on = opts.fetch(:delegate_on) { ::Phlex::SGML }
          delegate_name = opts.fetch(:delegate_name, "app")

          warn sprintf(DELEGATE_ERROR_MESSAGE, "delegate_on", delegate_on.inspect) unless delegate_on
          warn sprintf(DELEGATE_ERROR_MESSAGE, "delegate_name", delegate_name.inspect) unless delegate_name
        end

        app.opts[:phlex] = opts.dup
        app.opts[:phlex][:layout_handler] ||= DEFAULT_LAYOUT_HANDLER
        app.opts[:phlex][:context] ||= {}

        if delegate && delegate_on && delegate_name
          delegate_mod = Module.new do
            class_eval <<~RUBY, __FILE__, __LINE__ + 1
              def #{delegate_name}
                @_view_context
              end
            RUBY

            case delegate
            when Array
              delegate.each do |delegate|
                class_eval <<~RUBY, __FILE__, __LINE__ + 1
                  def #{delegate}(...)
                    #{delegate_name}.#{delegate}(...)
                  end
                RUBY
              end
            end
          end

          delegate_on.include(delegate_mod)
        end
      end

      module InstanceMethods
        # Retrieves or sets the layout.
        # When no argument is provided, it returns the current layout.
        # Use +nil+ or +false+ to disable layout.
        #
        # @param layout [Class, nil, false] The layout (a +Phlex::SGML+ class) to be set.
        # @return [Class, nil] The current layout (a +Phlex::SGML+ class) or nil if not set.
        def phlex_layout(layout = Undefined)
          case layout
          when Undefined
            opts.dig(:phlex, :layout)
          when nil, false
            opts[:phlex].delete(:layout)
          else
            if layout <= ::Phlex::SGML
              opts[:phlex][:layout] = layout
            else
              raise TypeError.new(layout)
            end
          end
        end

        # Retrieves or sets the layout options.
        # When no argument is provided, it returns the current layout options.
        # Use +nil+ to delete layout options.
        #
        # @note The {DEFAULT_LAYOUT_HANDLER} expects +layout_opts+ to be a +Hash+.
        # @param layout_opts [Object, nil] The layout options to be set, usually a +Hash+.
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
        # When no argument is provided, it returns the current layout handler.
        # Use +nil+ or +:default: to reset the layout handler to the {DEFAULT_LAYOUT_HANDLER}.
        #
        # @param handler [#call, nil, :default] The layout handler to be set.
        # @return [#call] The current layout handler.
        def phlex_layout_handler(handler = Undefined)
          case handler
          when Undefined
            opts.dig(:phlex, :layout_handler)
          when nil, :default
            opts[:phlex][:layout_handler] = DEFAULT_LAYOUT_HANDLER
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
