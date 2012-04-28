require 'test/helpers'

# Note: if you wanted to take this approach you'd usually wanna be using
# Resource::Object, or at least use Typisch::Typed to help make your
# resource class a typed class. But this is here to demonstrate & test a more
# direct if verbose approach:

describe "An Resource::Base resource where the data being serialized is itself, a resource with a URI etc" do

  class TestResourceClass
    include Resource::Base

    def initialize(uri, application_context, data)
      @uri = uri
      @application_context = application_context
      @foo = data[:foo]
      @bar = data[:bar]
    end

    def serialization_data; self; end
    def serialization_type; TEST_REGISTRY[:TestResourceClass]; end

    attr_reader :foo, :bar
  end

  TEST_REGISTRY.register do
    register_type_for_class TestResourceClass do
      property :foo, :integer
      property :bar, sequence(:string)
    end
  end

  include ResourceTestHelpers
  include WirerHelpers

  def setup
    @ctr = new_container do |ctr|
      ctr.add_instance({TestResourceClass => 'test-resource-class'},
        :features => [:classes_exposed_as_type_resources])
    end

    @resource = TestResourceClass.new('/under_test', @ctr.resource_application_context, :foo => 123, :bar => ['x','y','z'])

    self.root_resource = Class.new {include Doze::Router}.new
    root_resource.add_route('/types', :to => @ctr.type_index)
    root_resource.add_route('/under_test', :to => @resource)
  end

  it "should include the uris of resources being serialized, in their serialization" do
    get '/under_test'
    assert_equal({
      'foo'       => 123,
      'bar'       => ['x','y','z'],
      '_tag'      => '/types/test-resource-class',
      'version'   => 'main',
      'uri'       => '/under_test'
    }, last_response.json)
  end

  it "should when html is requested, include anchor tag links to the uris of serialized resources" do
    get '/under_test', {}, {'HTTP_ACCEPT' => 'text/html'}

    # check it makes this into an actual link
    assert_match /<a href=['"]\/under_test['"]>/, last_response.body
  end
end
