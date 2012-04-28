require 'test/helpers'

describe "An Resourced::Object resource class" do

  class TestObjectResourcedClass < Resourced::Object
    register_type TEST_REGISTRY do
      property :foo, :integer
      property :bar, sequence(:string)
    end

    def initialize(uri, app_context, properties)
      super(uri, app_context)
      @foo = properties[:foo]
      @bar = properties[:bar]
    end
  end

  include ResourcedTestHelpers
  include WirerHelpers

  def setup
    @ctr = new_container do |ctr|
      ctr.add_instance({TestObjectResourcedClass => 'test-object-resource-class'}, :features => [:classes_exposed_as_type_resources])
    end

    @resource = TestObjectResourcedClass.new('/under_test', @ctr.resource_application_context, :foo => 123, :bar => ['x','y','z'])

    self.root_resource = Class.new {include Doze::Router}.new
    root_resource.add_route('/types', :to => @ctr.type_index)
    root_resource.add_route('/under_test', :to => @resource)
  end

  it "should serialize itself according to its registered type, and include its uri in the serialization" do
    get '/under_test'
    assert_equal({
      'foo'       => 123,
      'bar'       => ['x','y','z'],
      '_tag'      => '/types/test-object-resource-class',
      'version'   => 'main',
      'uri'       => '/under_test'
    }, last_response.json)
  end

  it "should make properties accessible via subresources" do
    get '/under_test/property/foo'
    assert last_response.ok?
    assert_equal 123, last_response.json
  end

  it "should make properties with sequence types, accessible via sequence subresources with special additional structure" do
    get '/under_test/property/bar'
    assert last_response.ok?
    get '/under_test/property/bar/range/all'
    assert last_response.ok?
    assert_equal ['x','y','z'], last_response.json
    get '/under_test/property/bar/range/0-1'
    assert last_response.ok?
    assert_equal({"_tag"=>"array", "range_start"=>0, "total_items"=>3, "items"=>["x", "y"]}, last_response.json)
    # see tests for Resourced::Sequence for more
  end
end
