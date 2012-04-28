module MSP::Resource2
  module Serializer; end
  class Serializer::JsonableTypeResource < Typisch::JsonableTypeSerializer
    include Serializer::Resource

    def initialize(type_index, options={})
      super({:type_tag_key => '_tag', :value_class_to_type_tag => type_index.classes_to_uris}.merge(options))
      @type_index = type_index
    end

    def serialize_object(value, type, depth)
      result = super

      # this should probably be a property of the type serialized via the meta-schema,
      # but don't have time to make the Typisch changes at the mo
      if Typisch::Type::Object === value && depth == 0
        versions = @type_index.version_types_for_class(value.class_or_module)
        unless versions.empty?
          result['version_types_for_tag'] = (versions_json = {})
          versions.each do |version_name, version_type|
            versions_json[version_name] = @type_index.type_resource_uri_for_class_and_version(value.class_or_module, version_name.to_s)
          end
        end
      end
      result
    end

  end
end
