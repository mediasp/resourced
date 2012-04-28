module Resource
  class Object::MultiVersion < Object

    route('/version/{version}', :name => 'version_by_name') do |router, uri, params|
      router.version_resource(params[:version], uri)
    end

    def version_resource(name, uri=expand_route_template('versions_by_name', :version => name))
      type = self.class.version_type(name) and SerializedWithType.new(uri, self, type, @application_context)
    end

    class << self
      def register_version_type(name, registry, &block)
        type = super(name, registry, &block)
        version_types_by_string[name.to_s] = type
      end

      def version_types_by_string
        @version_types_by_string ||= {}
      end

      def version_type(key)
        super || @version_types_by_string[key]
      end
    end

  end
end
