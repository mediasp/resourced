module Resource
end

require 'doze'
require 'wirer'
require 'typisch'
require 'thin_models/struct'
require 'thin_models/struct/typed'
require 'thin_models/lazy_array'

require 'resource/application_context'
require 'resource/serializer/jsonable_resource'
require 'resource/serializer/html_resource'
require 'resource/serializer/jsonable_type_resource'
require 'resource/serializer/html_type_resource'
require 'resource/base'
require 'resource/router'
require 'resource/repository'
require 'resource/serialized_with_type'
require 'resource/object'
require 'resource/object/multi_version'
require 'resource/object/wrapped_model'
require 'resource/sequence'
require 'resource/repositories_index'
require 'resource/type_index'

