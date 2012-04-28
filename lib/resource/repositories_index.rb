# RepositoriesIndex serves a dual purpose. Firstly, it's an index resource which routes
# to a bunch of different repository resources for under specified aliases.
#
# But it's also a kind of service locator or factory for repository resources and the object
# resources within them, which helps find an appropriate repository resource for a given model
# class, or an appropriate Object::WrappedModel resource for a given model instance (going via
# the relevant repository resource).
#
# The application-wide ApplicationContext object depends on all available RepositoriesIndex
# and uses them to provide a centralised facility for this kind of service location.
#
# Some assumptions are made here, namely that your Repository resources will expose the model instances
# returned from the repository after wrapping in an Object::WrappedModel resource subclass.
#
# Room for change: the responsibilities could be split up a bit, it could be generalised a bit
# so it doesn't make as many assumptions, some of the service-locator/factory stuff could maybe be done
# via Wirer instead at the cost of having to add a load more things into the main wirer application.
module MSP::Resource2
  class RepositoriesIndex
    include Router

    wireable
    dependency :application_context, ApplicationContext

    class << self
      def exposed_repositories
        @exposed_repositories ||= {}
      end

    private

      def expose_repository(name, repo_class, resource_class, route_string="/#{route_string}", repo_options={})
        dependency(name, repo_class)
        model_class = repo_class.model_class
        route(route_string, :name => name.to_s) {|router,uri| router.repo_resources[model_class]}
        exposed_repositories[name] = [repo_class.model_class, repo_class, resource_class, repo_options]
      end
    end

    attr_reader :repo_resources, :repos

    def initialize(uri, dependencies)
      @uri = uri
      @repo_resources = {}
      @repos = {}
      @application_context = dependencies[:application_context]
      self.class.exposed_repositories.each do |name, (model_class, repo_class, resource_class, repo_options)|
        repo = dependencies[name]
        uri = expand_route_template(name.to_s, {})
        repo_resource = Repository.new(uri, repo, repo_options) do |uri, model|
          resource_class.new(uri, model, @application_context)
        end
        @repo_resources[model_class] = repo_resource
        @repos[model_class] = repo
      end
    end

    def resource_from_model(model)
      repo_resource = @repo_resources[model.class] or raise "Don't know how to construct resource for #{model.class}"
      repo_resource.resource(model)
    end
    
    def resource_from_model_class_and_id(model_class, id)
      repo_resource = @repo_resources[model_class] or raise "Don't know how to construct resource for #{model.class}"
      repo_resource.resource_by_id(id)
    end
  end
end
