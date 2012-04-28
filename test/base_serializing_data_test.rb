require 'test/helpers'
require 'test/api/resource/helpers'
require 'ostruct'

MSP.require_plugin('resource2')

class TestDataClass < OpenStruct; end

MSP.register_types do
  register_type_for_class TestDataClass do
    property :a, :integer
    property :b, sequence(:string)
  end
end

describe "A basic MSP::Resource2::Base resource serializing some typed data" do
  include ResourceTestHelpers
  
  setup do
    @msp_app = MSP.new_application('resource2' => {:type_index_uri => '/types'}) do |app|
      app.add_instance({TestDataClass => 'test-data-class'}, :features => [:classes_exposed_as_type_resources])
    end

    @type = MSP::TYPE_REGISTRY[:TestDataClass]    
    @data = TestDataClass.new(:a => 123, :b => ['x','y','z'])

    @resource = MSP::Resource2::SerializedWithType.new('/under_test', @data, @type, @msp_app.resource_application_context)
    
    self.root_resource = Class.new {include Doze::Router}.new
    root_resource.add_route('/types', :to => @msp_app.type_index)
    root_resource.add_route('/under_test', :to => @resource)    
  end
  
  it "should by default serialize the data as json in the application/vnd.msp+json media type and in utf-8" do
    get '/under_test'
    assert_equal "application/vnd.msp+json", last_response.media_type
    assert_equal "utf-8", last_response.content_charset
    assert last_response.json
  end

  it "should when json is requested serialize the data as json in the application/vnd.msp+json media type and in utf-8" do
    get '/under_test', {}, {'HTTP_ACCEPT' => 'application/json'}
    assert_equal "application/vnd.msp+json", last_response.media_type
    assert_equal "utf-8", last_response.content_charset

    get '/under_test', {}, {'HTTP_ACCEPT' => 'application/vnd.msp+json'}
    assert_equal "application/vnd.msp+json", last_response.media_type
    assert_equal "utf-8", last_response.content_charset
  end

  it "should serialize the serialization_data using type metadata from the serialization_type, and using some MSP-specific default settings for the serializer" do
    get '/under_test'
    assert_equal({
      'a'       => 123,
      'b'       => ['x','y','z'],
      '_tag'    => '/types/test-data-class',
      'version' => 'main'
    }, last_response.json)
  end
  
  it "should use working uris as type tags, where the uri resolves to a resource describing the type" do
    get '/under_test'
    get last_response.json['_tag']
    assert_equal "application/vnd.msp+json", last_response.media_type
    type_json = last_response.json
    assert_equal 'object', type_json['_tag']
    assert_equal({
        "a" => {"_tag" => "numeric", "tag" => "Integral"},
        "b" => {"_tag" => "sequence", "type" => {"_tag" => "string"}}
    }, type_json['property_names_to_types'])
    assert_equal "/types/test-data-class", type_json['tag']
  end

  it "should when html is requested, serialize the data in a browser-friendly HTML format with uris turned into anchor tags" do
    get '/under_test', {}, {'HTTP_ACCEPT' => 'text/html'}
    assert_equal "text/html", last_response.media_type
    assert_equal "utf-8", last_response.content_charset
    
    # kinda crude prodding to look for something which looks plausibly like some HTML with the appropriate data serialized in it
    assert_match /<html>.*<\/html>/m, last_response.body
    assert_match /x.*y.*z/m, last_response.body
    assert_match /123/, last_response.body
    # check it makes this into an actual link
    assert_match /<a href=['"]\/types\/test-data-class['"]>/, last_response.body
  end
end
