# Basic superclass for resources, which provides for serialization of the resource
# in standard media types.
#
# You need to override get_data to return a JSON-able data structure.
module Resource
  class SerializedWithType
    include Base

    def initialize(uri, data, type, application_context)
      @uri = uri
      @serialization_data = data
      @serialization_type = type
      @application_context = application_context
    end
  end
end
