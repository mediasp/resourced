require 'typisch/serialization'

module MSP::Resource2
  module Serializer; end
  module Serializer::Resource
    ARRAY_TAGS = {
      ThinModels::LazyArray                   => 'array',
      ThinModels::LazyArray::MemoizedLength   => 'array',
      ThinModels::LazyArray::Memoized         => 'array',
      ThinModels::LazyArray::Mapped           => 'array',
      ThinModels::LazyArray::Memoized::Mapped => 'array',
      ::Array                                 => 'array'
    }
  end

  class Serializer::JsonableResource < Typisch::JsonableSerializer
    include Serializer::Resource

    def initialize(type, type_index, options={})
      @type_index = type_index
      super(type,
        :class_to_type_tag => options[:class_to_type_tag] || type_index.classes_to_uris.merge(ARRAY_TAGS),
        :type_tag_key      => options[:type_tag_key]      || '_tag'
      )
      @compatibility_tag_key           = options[:compatibility_tag_key]
      @class_name_to_compatibility_tag = options[:class_name_to_compatibility_tag]
      @uri_key                         = options[:uri_key]        || '_uri'
      @version_key                     = options[:version_key]    || '_version'
      @version_as_uri                  = options[:version_as_uri] != false
    end

    def serialize_object(value, type, depth)
      result = super
      if Doze::Resource === value && (uri = value.uri)
        result[@uri_key] = uri
      end
      if @compatibility_tag_key && (compat_tag = @class_name_to_compatibility_tag[value.class.to_s])
        result[@compatibility_tag_key] = compat_tag
      end
      if type.version
        result[@version_key] = if @version_as_uri
          @type_index.type_resource_uri_for_class_and_version(value.class, type.version)
        else
          type.version
        end
      end
      result
    end

    def serialize_slice(value, type, depth)
      result = super
      if @compatibility_tag_key && (compat_tag = @class_name_to_compatibility_tag[value.class.to_s])
        result[@compatibility_tag_key] = compat_tag
      end            
      if Doze::Resource === value && (uri = value.uri)
        result[@uri_key] = uri
      end
      result
    end

    def self.jsonable_routes(router)
      result = []
      router.routes.each do |route|
        # For now we hold off exposing templates for the media-type-specific subresources on every separate resource,
        # since it adds a fair bit of redundancy
        next if route.name == 'specific_media_type'
        result << {'href' => route.template(router.router_uri_prefix), 'rel' => route.name}
      end
      {'_routes' => result}
    end
  end
end
