# Resource wrapper for a repository, exposing 'get_by_id'.
#
# Requires you specify a resource class which it will route to for the resources
# themselves.
module Resource
  class Repository
    include Router

    URI_TEMPLATE_STYLES = {
      :hex   => '{/id.quadhexbytes*}',
      :plain => '/{id}'
    }

    def initialize(uri, repository, options={}, &construct_resource)
      @uri = uri
      @repository = repository
      @construct_resource = construct_resource
      
      template = URI_TEMPLATE_STYLES[options[:uri_template_style] || :hex]
      add_route(template, :name => 'object_by_id') do |router, uri, params|
        router.resource_by_id(params[:id], uri)
      end
    end

    def resource_by_id(id, uri=nil)
      r = @repository.get_by_id(id)
      r && resource(r, uri)
    end

    def resource(model, uri=nil)
      uri ||= expand_route_template('object_by_id', :id => model.id)
      @construct_resource.call(uri, model)
    end

  end
end
