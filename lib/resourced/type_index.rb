module Resourced
  class TypeIndex
    include Router

    attr_reader :classes_to_uris, :registry

    wireable
    dependency :expose_classes, :features => :classes_exposed_as_type_resources, :class => ::Hash, :multiple => true, :optional => true
    dependency :type_registry, Typisch::Registry

    def initialize(uri, deps)
      @uri = uri
      @registry = deps[:type_registry]

      @classes_to_aliases = deps[:expose_classes].inject({}, &:merge!)
      @aliases_to_classes = @classes_to_aliases.invert

      @classes_to_uris = {}
      @classes_to_aliases.each do |klass, name|
        @classes_to_uris[klass] = expand_route_template('type_by_tag', :name => name)
      end
    end

    route("/{name}", :name => 'type_by_tag') {|router,uri,params| router.type_resource(params[:name], uri)}

    def type_resource(name, uri=expand_route_template('type_by_tag', :name => name))
      klass = @aliases_to_classes[name] and
        Type::WithVersions.new(uri, @registry[klass], self)
    end

    def type_resource_for_class(klass)
      name = @classes_to_aliases[klass] and type_resource(name)
    end

    def type_resource_for_class_and_version(klass, version)
      name = @classes_to_aliases[klass] and type_resource(name).get_route('version', version)
    end

    def type_resource_uri_for_class(klass)
      @classes_to_uris[klass]
    end

    def type_resource_uri_for_class_and_version(klass, version)
      type_resource_for_class(klass).expand_route_template('version_of_tag', :version => version)
    end

    def version_types_for_class(klass)
      @registry.types_by_class_and_version[klass] || {}
    end
  end

  class Type
    include Doze::Resource

    def initialize(uri, type, type_index)
      @uri = uri
      @type = type
      @type_index = type_index
    end

    def get
      [
        Doze::Serialization::JSON.entity_class.new(Base::JSON_MEDIA_TYPE, :encoding => 'utf-8') do
          Serializer::JsonableTypeResourced.new(@type_index).serialize(@type)
        end,
        Doze::Entity.new(Base::HTML_MEDIA_TYPE, :encoding => 'utf-8') do
          Serializer::HTMLTypeResourced.new(@type_index).serialize(@type, (self if is_a?(Doze::Router)))
        end
      ]
    end

    class WithVersions < Type
      include Doze::Router

      route("/version/{version}", :name => 'version_of_tag') do |router, uri, params|
        router.version_type_resource(params[:version], uri)
      end

      def version_type_resource(version, uri=expand_route_template('version_of_tag', :version => version))
        _, version_type = @type_index.version_types_for_class(@type.class_or_module).find {|k,v| k.to_s == version}
        version_type && Type.new(uri, version_type, @type_index)
      end
    end
  end
end
