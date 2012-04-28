require 'doze/utils'

module Resource
  module Serializer; end

  # Apologies for the mess, a TODO would be to DRY up the HTML serialization logic
  class Serializer::HTMLTypeResource < Serializer::HTMLResource
    include Serializer::Resource

    def initialize(type_index, options={})
      super(Typisch::META_TYPES[:"Typisch::Type"], type_index, options.merge(
        :class_to_type_tag => Typisch::JsonableTypeSerializer::CLASS_TO_SERIALIZED_TAG
      ))
      @value_class_to_type_tag = type_index.classes_to_uris
    end

    def serialize_object(type, type_of_type, depth)
      if depth > 0
        if Typisch::Type::Object === type && type.version
          pairs = [
            "<tr><td><span>version</span></td><td>#{self.class.make_string_html(type.version)}</td></tr>",
            "<tr><td><span>tag</span></td><td>#{self.class.make_link_html(@value_class_to_type_tag[type.class_or_module])}</td></tr>"
          ]
        elsif type_of_type[:name] && type.name
          pairs = [
            "<tr><td><span>name</span></td><td>#{self.class.make_string_html(type.name)}</td></tr>"
          ]
        end
      end

      unless pairs
        pairs = type_of_type.property_names_to_types.map do |prop_name,prop_type|
          next if prop_name == :tag && Typisch::Type::Object === type
          v = type.send(prop_name)
          "<tr><td>#{self.class.make_string_html(prop_name)}</td><td>#{serialize_type(v, prop_type, depth+1)}</td></tr>" unless v.nil?
        end.compact
        if Typisch::Type::Object === type
          pairs << "<tr><td><span>tag</span></td><td>#{self.class.make_link_html(@value_class_to_type_tag[type.class_or_module])}</td></tr>"
          if depth == 0
            versions = @type_index.version_types_for_class(type.class_or_module)
            unless versions.empty?
              items = versions.map do |version_name, version_type|
                uri = @type_index.type_resource_uri_for_class_and_version(type.class_or_module, version_name.to_s)
                "<tr><td><span>#{self.class.escape(version_name)}</span></td><td>#{self.class.make_link_html(uri)}</td></tr>"
              end
              pairs << "<tr><td><span>version_types_for_tag</span></td><td><table rules='all' frame='void'>#{items.join("\n")}</table>" unless items.empty?
            end
          end
        end
      end
      pairs.unshift "<tr><td>#{self.class.make_string_html(@type_tag_key)}</td><td>#{self.class.make_string_html(@class_to_type_tag[type.class])}</td></tr>"

      "<table rules='all' frame='void'>#{pairs.join("\n")}</table>"
    end
  end
end
