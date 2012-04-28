module Resource
  class Object
    include Base
    include Doze::Router
    include Typisch::Typed

    def initialize(uri, application_context)
      @uri = uri
      @application_context = application_context
    end

    def serialization_data; self; end
    def serialization_type; self.class.type; end

    route("/property/{property}", :name => 'property_by_name') do |router, uri, params|
      router.property_resource(params[:property], uri)
    end

    def property_resource(name, uri=expand_route_template('property_by_name', :property => name))
      type = property_type(name) or return
      case type
      when Typisch::Type::Sequence
        options = self.class.property_resource_options[name.to_sym] || {}
        Sequence.new(uri, send(name), type, @application_context, options)
      else
        SerializedWithType.new(uri, send(name), type, @application_context)
      end
    end

    def property_type(name)
      # avoids doing a to_sym on possibly-arbitrary-user-input string
      type.property_names_to_types.each {|n,type| return type if n.to_s == name.to_s}
    end

    def self.register_type(registry=nil, derived_from=nil, &block)
      super(registry || MSP::TYPE_REGISTRY, derived_from, &block)
    end

    def self.property_resource_options
      @property_resource_options ||= {}
    end
  end
end
