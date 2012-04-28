module Resourced
  # A kind of a service locator / hub / factory providing various facilities for resource-related
  # stuff which is used throughout the whole routing tree of resources.
  #
  # If that sounds a bit handwavey and global, it's probably because it is; feel free to split up
  # if you can find a better more localised way of doing this.
  #
  # Also: the aim is to change Doze so the Doze::Application can be
  # used as a context object like this, and so routing blocks get passed
  # an environment object with access to this doze-application-level context
  # and other things, rather than just a session.
  #
  # For now though, we're manually creating it and passing it around as a
  # separate object.
  #
  # The main global things it helps with at present are: constructing wrapper resources for models
  # in a generic way which 'knows' about all the ways it's possible to construct resources which expose
  # models via routing chains like so:
  #   RepositoriesIndex -> '/Repository -> Object::WrappedModel
  # Also, providing access to the TypeIndex, which gives all serializers some knowledge about the
  # type resources which can be linked to to provide browsable metadata about the types of objects.
  class ApplicationContext < Wirer::Service
    setter_dependency :repositories_indexes, :class => "Resourced::RepositoriesIndex", :multiple => true, :optional => true
    setter_dependency :type_index, :class => "Resourced::TypeIndex"

    def repositories_indexes=(repo_indexes)
      @repos          = repo_indexes.inject({}) {|hash,index| hash.merge!(index.repos)}
      @repo_resources = repo_indexes.inject({}) {|hash,index| hash.merge!(index.repo_resources)}
    end

    def resource_from_model(model)
      repo_resource = @repo_resources[model.class] or raise "Don't know how to construct resource for #{model.class}"
      repo_resource.resource(model)
    end

    def repository_resource_for_model_class(model_class)
      @repos[model_class]
    end

    # For now we override various options to the serializers for backwards compatibility reasons:
    SERIALIZATION_OPTIONS = {
      :uri_key                         => 'uri',
      :version_key                     => 'version',
      :version_as_uri                  => false,
      :compatibility_tag_key           => 'media_type',
      :class_name_to_compatibility_tag => {}
    }

    def jsonable_serializer_for_type(type)
      Serializer::JsonableResourced.new(type, @type_index, SERIALIZATION_OPTIONS)
    end

    def html_serializer_for_type(type)
      Serializer::HTMLResourced.new(type, @type_index, SERIALIZATION_OPTIONS)
    end
  end
end
