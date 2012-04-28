# Basic superclass for MSP resources, which provides for serialization of the resource
# in standard MSP media types.
#
# You need to override get_data to return a JSON-able data structure.
module Resource
  module Base
    JSON_MEDIA_TYPE = Doze::Serialization::JSON.register_derived_type('application/vnd.msp')
    HTML_MEDIA_TYPE = Doze::MediaType.new('text/html', :extension => 'html')
    HTML_MEDIA_TYPE.register_extension!

    include Doze::Resource

    def get
      [
        Doze::Serialization::JSON.entity_class.new(JSON_MEDIA_TYPE, :encoding => 'utf-8') do
          application_context.jsonable_serializer_for_type(serialization_type).serialize(serialization_data)
        end,
        Doze::Entity.new(HTML_MEDIA_TYPE, :encoding => 'utf-8') do
          application_context.html_serializer_for_type(serialization_type).serialize(serialization_data)
        end,
        MSP::Entity::JSONInHTML.new(MSP::Entity::JSONInHTML::MEDIA_TYPE, :encoding => 'utf-8') do
          application_context.jsonable_serializer_for_type(serialization_type).serialize(serialization_data)
        end
      ]
    end

    attr_reader :application_context, :serialization_data, :serialization_type

    # We explictly disable caching by default for MSP resources, to stop IE's auto-caching of ajax GETs
    def cacheable?; false; end
  end
end
