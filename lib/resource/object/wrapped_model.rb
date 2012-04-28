module Resource
  module Object::WrappedModel
    def self.included(klass)
      super
      klass.extend(ClassMethods)
    end

    def initialize(uri, model, application_context)
      @uri = uri
      @model = model
      @application_context = application_context
    end

    # TODO: this is sort of bypassing wirer; if a resource has a dependency on repositories
    # for other model classes, maybe it should declare these dependencies with and get constructed
    # via wirer?
    #
    # For now though, I'm letting these resources be constructed directly via a RepositoryIndex,
    # if we have it go via wirer maybe check there isn't too much overhead added
    def repo_for(model_class)
      @application_context.repository_resource_for_model_class(model_class)
    end

    def wrap_models(array)
      array && array.map {|item| item && @application_context.resource_from_model(item)}
    end

    def wrap_model(model)
      model && @application_context.resource_from_model(model)
    end

    module ClassMethods
      def wrap_model_class(model_class, registry=MSP::TYPE_REGISTRY, &block)
        raise "model class to be wrapped must be Typisch::Typed" unless model_class < Typisch::Typed
        @wrapped_class = model_class
        @wrapped_type = wrapped_type = model_class.type
        klass = self

        register_type(registry, wrapped_type) do
          extend WrappingDSL
          self.wrapped_type = wrapped_type
          self.wrapper_class = klass
          instance_eval(&block)
        end

        the_type = type
        the_type_alias = :"wrapped_as_resource__#{wrapped_type.name}"
        registry.register do
          registry.register_type(the_type_alias, the_type)
        end
      end

      def type_available
        # don't define attribute methods etc here
      end

      # When included in a MultiVersion object class, we also register version types
      # with an alias based off the model class being wrapped. This helps the
      # expose_wrapped_as_resource helpers to know what to use when asked to
      # expose a property wrapped in a particular version.
      def register_version_type(name, registry=MSP::TYPE_REGISTRY, &block)
        the_type = super
        the_type_alias = :"wrapped_as_resource__#{@wrapped_type.name}__#{name}"
        registry.register do
          registry.register_type(the_type_alias, the_type)
        end
      end

      def delegate_to_model(name)
        class_eval "def #{name}; @model.#{name}; end", __FILE__, __LINE__
      end

      def delegate_to_model_wrapped_as_resource(name)
        class_eval "def #{name}; wrap_model(@model.#{name}); end", __FILE__, __LINE__
      end

      def delegate_to_model_wrapped_as_resources(name)
        class_eval "def #{name}; wrap_models(@model.#{name}); end", __FILE__, __LINE__
      end


      module WrappingDSL
      private
        attr_accessor :wrapped_type, :wrapper_class

        def wrapped_property_type(name)
          wrapped_type[name] or raise "No such property #{name.inspect} on the type of model being wrapped"
        end

        # we rely on a convention that a resource class intended to wrap a given model will have its type
        # registered as :"wrapped_as_resource__#{name_of_original_type}" in addition to the normal registration,
        # meaning we know ahead of time how to refer to its type even if it's declared in a class which hasn't
        # been loaded yet
        def wrap_type_as_resource_type(type, version=nil)
          raise "Type #{type.inspect} had no name when trying to wrap as a resource type" unless type.name
          if version
            :"wrapped_as_resource__#{type.name}__#{version}"
          else
            :"wrapped_as_resource__#{type.name}"
          end
        end

        def wrap_non_null_types(type)
          case type
          when Typisch::Type::Union
            union(*type.alternative_types.map do |t|
              if Typisch::Type::Null === t then :null else yield(t) end
            end)
          else
            yield(type)
          end
        end

        def expose(*names)
          names.each do |name|
            derive_property(name)
            wrapper_class.delegate_to_model(name)
          end
        end

        def expose_wrapped_as_resource(name, options={})
          type = wrapped_property_type(name)
          new_type = wrap_non_null_types(type) {|t| wrap_type_as_resource_type(t, options[:version])}
          property(name, new_type)
          wrapper_class.delegate_to_model_wrapped_as_resource(name)
        end

        def expose_wrapped_as_resources(name, options={})
          type = wrapped_property_type(name)
          new_type = wrap_non_null_types(type) do |seq_type|
            raise "expected sequence type for expose_wrapped_as_resources" unless Typisch::Type::Sequence === seq_type
            sequence(
              wrap_non_null_types(seq_type.type) {|t| wrap_type_as_resource_type(t, options[:version])},
              :slice => options[:slice], :total_length => options[:total_length]
            )
          end
          property(name, new_type)
          wrapper_class.delegate_to_model_wrapped_as_resources(name)
          max_length = options[:max_length]
          wrapper_class.property_resource_options[name] = {:max_length => max_length} if max_length
        end

      end

    end

  end
end
