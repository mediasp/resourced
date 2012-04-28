require 'test/helpers'
require 'test/api/resource/helpers'

describe "A more involved usage scenario with Resource::Object::MultiVersion" do

  class TestMultiVersion1 < Resource::Object::MultiVersion
    register_type do
      property :a, :integer
      property :b, :integer
      property :c, :integer
    end

    register_version_type :ab do
      derive_properties :a, :b
    end

    register_version_type :bc do
      derive_properties :b, :c
    end

    def initialize(uri, app_context, properties)
      super(uri, app_context)
      properties.each {|k,v| instance_variable_set(:"@#{k}", v)}
    end
  end

  class TestMultiVersion2 < Resource::Object::MultiVersion
    register_type do
      property :foo, :integer
      property :bar, :TestMultiVersion1
      property :baz, sequence(:string)
    end
    
    register_version_type :bar_ab do
      derive_property :bar, :version => :ab
    end

    # a good example here: we specify the bar property only be serialized in its 'bc' version (not the bigger main version),
    # and only a partial slice of the 'baz' array property be serialized.
    register_version_type :foo_and_bar_bc_and_baz_0_1 do
      derive_property :foo
      derive_property :bar, :version => :bc
      derive_property :baz, :slice => (0..1)
    end
    
    def initialize(uri, app_context, properties)
      super(uri, app_context)
      properties.each {|k,v| instance_variable_set(:"@#{k}", v)}
    end
  end

  include ResourceTestHelpers
  
  def setup
    @msp_app = MSP.new_application('resource2' => {:type_index_uri => '/types'}) do |app|
      app.add_instance({
        TestMultiVersion1 => 'test-multi-version-1',
        TestMultiVersion2 => 'test-multi-version-2'
      }, :features => [:classes_exposed_as_type_resources])
    end
        
    @resource1 = TestMultiVersion1.new('/mv1', @msp_app.resource_application_context, :a => 1, :b => 2, :c => 3)
    @resource2 = TestMultiVersion2.new('/mv2', @msp_app.resource_application_context, :foo => 99, :bar => @resource1, :baz => ['x','y','z'])
    
    self.root_resource = Class.new {include Doze::Router}.new
    root_resource.add_route('/types', :to => @msp_app.type_index)
    root_resource.add_route('/mv1', :to => @resource1)
    root_resource.add_route('/mv2', :to => @resource2)
  end
  
  it "should serialize itself according to its main registered type, and include its uri in the serialization" do
    get '/mv1'
    assert_equal({
      'a'       => 1,
      'b'       => 2,
      'c'       => 3,
      '_tag'    => '/types/test-multi-version-1',
      'version' => 'main',
      'uri'     => '/mv1'
    }, last_response.json)

    get '/mv2'
    assert_equal({
      'foo' => 99,
      'bar' => {
        'a'       => 1,
        'b'       => 2,
        'c'       => 3,
        '_tag'    => '/types/test-multi-version-1',
        'version' => 'main',
        'uri'     => '/mv1'        
      },
      'baz'     => ['x','y','z'],
      '_tag'    => '/types/test-multi-version-2',
      'version' => 'main',
      'uri'     => '/mv2'
    }, last_response.json)
  end
  
  it "should make properties accessible via subresources, serializing them using the as specified by the main type for the object" do
    get '/mv1/property/a'
    assert_equal 1, last_response.json
    get '/mv1/property/b'
    assert_equal 2, last_response.json
    get '/mv1/property/c'
    assert_equal 3, last_response.json

    get '/mv2/property/foo'
    assert_equal 99, last_response.json
    get '/mv2/property/bar'
    assert_equal({
      'a'       => 1,
      'b'       => 2,
      'c'       => 3,
      '_tag'    => '/types/test-multi-version-1',
      'version' => 'main',
      'uri'     => '/mv1'       
    }, last_response.json)
  end

  it "should make properties with sequence types, accessible via sequence subresources with special additional structure" do
    get '/mv2/property/baz'
    assert last_response.ok?
    get '/mv2/property/baz/range/all'
    assert last_response.ok?
    assert_equal ['x','y','z'], last_response.json
    get '/mv2/property/baz/range/0-1'
    assert last_response.ok?
    assert_equal({"_tag"=>"array", "range_start"=>0, "total_items"=>3, "items"=>["x", "y"]}, last_response.json)
    # see tests for Resource::Sequence for more
  end

  it "should make version subresources available which serialize (a subset of) the data as specified by the derived version type" do
    get '/mv1/version/ab'
    assert_equal({
      'a'       => 1,
      'b'       => 2,
      '_tag'    => '/types/test-multi-version-1',
      'version' => 'ab',
      'uri'     => '/mv1'
    }, last_response.json)

    get '/mv1/version/bc'
    assert_equal({
      'b'       => 2,
      'c'       => 3,
      '_tag'    => '/types/test-multi-version-1',
      'version' => 'bc',
      'uri'     => '/mv1'
    }, last_response.json)

    get '/mv2/version/bar_ab'
    assert_equal({
      'bar' => {
        'a'       => 1,
        'b'       => 2,
        '_tag'    => '/types/test-multi-version-1',
        'version' => 'ab',
        'uri'     => '/mv1'
      },
      '_tag'    => '/types/test-multi-version-2',
      'version' => 'bar_ab',
      'uri'     => '/mv2'
    }, last_response.json)

    get '/mv2/version/foo_and_bar_bc_and_baz_0_1'
    assert_equal({
      'foo' => 99,
      'bar' => {
        'b'       => 2,
        'c'       => 3,
        '_tag'    => '/types/test-multi-version-1',
        'version' => 'bc',
        'uri'     => '/mv1'
      },
      'baz' => {"_tag"=>"array", "range_start"=>0, "total_items"=>3, "items"=>["x", "y"]},
      '_tag'    => '/types/test-multi-version-2',
      'version' => 'foo_and_bar_bc_and_baz_0_1',
      'uri'     => '/mv2'
    }, last_response.json)
  end
  
  it "should use the version name 'main' for the, well, the main version of the object from which others are derived" do
    get '/mv1'
    assert_equal 'main', last_response.json['version']
  end
end
