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
    # - `:context` (+Hash+): The context that is passed to the rendering call. (default: `{}`)
    # - `:delegate`: Define if or which methods should be delegated to the Roda app:
    #     + `true` (default): Create a single `app` method that delegates to the Roda app.
    #     + `false`: Do not create any delegate methods.
    #     + `Array<Symbol,String>`: Delegate the named methods to the Roda app.
    # - `:delegate_on`: Class or module to define delegation methods on. Defaults to +::Phlex::SGML+.
    #    + Use this option to limit delegation methods to a application specific class or module
    #      (like "ApplicationView") to avoid polluting the global namespace.
    # - `:delegate_name`: The name of the method that delegates to the Roda app. Defaults to `"app"`.
    # - `:context_key`: The context key to use to access the Roda app. Defaults to `:__roda_app__`.
    module Phlex
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
          context_key = opts.fetch(:context_key, :__roda_app__)

          raise ArgumentError, "context_key must be set when delegating" unless context_key

          warn sprintf(DELEGATE_ERROR_MESSAGE, "delegate_on", delegate_on.inspect) unless delegate_on
          warn sprintf(DELEGATE_ERROR_MESSAGE, "delegate_name", delegate_name.inspect) unless delegate_name
        end

        app.opts[:phlex] = opts.dup
        app.opts[:phlex][:layout_handler] ||= DEFAULT_LAYOUT_HANDLER
        app.opts[:phlex][:context] ||= {}

        if delegate && delegate_on && delegate_name
          app.opts[:phlex][:context_key] = context_key

          delegate_mod = Module.new do
            class_eval <<~RUBY, __FILE__, __LINE__ + 1
              def #{delegate_name}
                context[#{context_key.inspect}]
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
        # Retrieves the layout class.
        # @return [Class, nil] The current layout (a +Phlex::SGML+ class) or nil if not set.
        def phlex_layout
          return @_phlex_layout if defined?(@_phlex_layout)
          @_phlex_layout = opts.dig(:phlex, :layout)
        end

        # Sets the layout class.
        #
        # @param layout [Class, nil] The layout class to be set.
        # @return [Class, nil] The layout class that was set.
        def set_phlex_layout(layout)
          if !layout || layout <= ::Phlex::SGML
            @_phlex_layout = layout
          else
            raise TypeError.new(layout)
          end
        end

        # Retrieves the layout options hash.
        # @return [Object, nil] The current layout options or nil if not set.
        # @note Layout options set via the plugin configuration will get `dep`ed
        #       for the current request. Be aware that this is a shallow copy and
        #       changes to nested objects will affect the original object, that is
        #       all subsequent requests. This is *unsafe* and should be avoided:
        #       ```ruby
        #       plugin :phlex, layout_opts: {key: {nested: "value"}}
        #       # ...
        #       # UNSAFE: Changes to phlex_layout_opts[:key] will affect the plugin config.
        #       phlex_layout_opts[:key][:nested] = "other value"
        #       ```
        def phlex_layout_opts
          return @_phlex_layout_opts if defined?(@_phlex_layout_opts)
          @_phlex_layout_opts = opts.dig(:phlex, :layout_opts).dup
        end

        # Sets the layout options.
        # @param layout_opts [Object, nil] The layout options to be set.
        # @return [Object, nil] The layout options that were set.
        # @note The {DEFAULT_LAYOUT_HANDLER} expects +layout_opts+ to be a +Hash+.
        def set_phlex_layout_opts(layout_opts)
          @_phlex_layout_opts = layout_opts
        end

        # Retrieves the layout handler.
        # @return [#call] The current layout handler.
        def phlex_layout_handler
          return @_phlex_layout_handler if defined?(@_phlex_layout_handler)
          @_phlex_layout_handler = opts.dig(:phlex, :layout_handler)
        end

        # Sets the layout handler.
        # Use +nil+ or +:default: to reset the layout handler to the {DEFAULT_LAYOUT_HANDLER}.
        def set_phlex_layout_handler(handler)
          @_phlex_layout_handler = case handler
          when nil, :default
            DEFAULT_LAYOUT_HANDLER
          else
            handler
          end
        end

        # Retrieves the Phlex context.
        # @return [Hash, nil] The current Phlex context.
        def phlex_context
          return @_phlex_context if defined?(@_phlex_context)
          @phlex_context = opts.dig(:phlex, :context).dup
        end

        # Sets the Phlex context.
        # @param context [Hash] The Phlex context to be set.
        # @return [Hash] The Phlex context that was set.
        def set_phlex_context(context)
          @_phlex_context = context
        end

        # Renders a Phlex object.
        # @param obj [Phlex::SGML] The Phlex object to be rendered.
        # @param layout [Class, nil] The layout to be used for rendering. Defaults to the layout set by {#phlex_layout}.
        #   - The layout class will be initialized with the object and layout options from #{phlex_layout_opts} via {#phlex_layout_handler}.
        #   - +nil+ or +false+ will disable layout and render the +obj+ directly.
        # @param context [Hash, nil] The Phlex context to be used for rendering. Defaults to the context set by {#phlex_context}.
        # @param content_type [String, nil] The content type of the response.
        # @param stream [Boolean] Whether to stream the response or not.
        def phlex(obj, layout: phlex_layout, context: phlex_context, content_type: nil, stream: false)
          raise TypeError.new(obj) unless obj.is_a?(::Phlex::SGML)

          content_type ||= "image/svg+xml" if obj.is_a?(::Phlex::SVG)
          response["Content-Type"] = content_type if content_type

          renderer = if layout
            phlex_layout_handler.call(layout, phlex_layout_opts, obj)
          else
            obj
          end

          context ||= {}
          context[opts[:phlex][:context_key]] = self

          if stream
            self.stream do |out|
              renderer.call(out, context: context)
            end
          else
            renderer.call(context: context)
          end
        end
      end
    end

    register_plugin :phlex, Phlex
  end
end
