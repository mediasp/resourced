module Resourced
end

require 'doze'
require 'wirer'
require 'typisch'
require 'thin_models/struct'
require 'thin_models/struct/typed'
require 'thin_models/lazy_array'

require 'resourced/application_context'
require 'resourced/serializer/jsonable_resource'
require 'resourced/serializer/html_resource'
require 'resourced/serializer/jsonable_type_resource'
require 'resourced/serializer/html_type_resource'
require 'resourced/base'
require 'resourced/router'
require 'resourced/repository'
require 'resourced/serialized_with_type'
require 'resourced/object'
require 'resourced/object/multi_version'
require 'resourced/object/wrapped_model'
require 'resourced/sequence'
require 'resourced/repositories_index'
require 'resourced/type_index'

