require 'test/helpers'
require 'test/api/resource/helpers'

describe "Resource::Repository exposing model class instances wrapped via Resource2::SerializedWithType" do

  class TestModelFromRepo < ThinModels::Struct::Typed
    register_type do
      property :id, :integer
      property :foo, :integer
      property :bar, :integer
    end
    identity_attribute :id
  end

  class TestRepo
    include Persistence::IdentitySetRepository
    def self.model_class; TestModelFromRepo; end
  end

  include ResourceTestHelpers
  
  def setup
    @msp_app = MSP.new_application('resource2' => {:type_index_uri => '/types'}) do |app|
      app.add_instance({TestModelFromRepo => 'test-model-from-repo'}, :features => [:classes_exposed_as_type_resources])
    end
  end
  
  def set_up_repo(options={})
    @repo = TestRepo.new
    @repo_resource = Resource::Repository.new('/repo', @repo, options) do |uri, model|
      Resource::SerializedWithType.new(uri, model, TestModelFromRepo.type, @msp_app.resource_application_context)
    end
        
    self.root_resource = Class.new {include Doze::Router}.new
    root_resource.add_route('/types', :to => @msp_app.type_index)
    root_resource.add_route('/repo', :to => @repo_resource)    
  end
  
  it "should make objects from the repository accessible by their IDs, using a quadhexbytes URL pattern by default for presumed integer IDs" do
    set_up_repo
    @repo.expects(:get_by_id).with(0xff).returns(TestModelFromRepo.new(:id => 0xff, :foo => 1, :bar => 2))
    get '/repo/00/00/00/ff'
    assert_equal({
      "_tag"    => "/types/test-model-from-repo",
      "version" => "main",
      "id"      => 255,
      "foo"     => 1,
      "bar"     => 2,
    }, last_response.json)
  end
  
  it "should 404 when the ID isn't in the repo" do
    set_up_repo
    @repo.expects(:get_by_id).with(0xff).returns(nil)
    get '/repo/00/00/00/ff'
    assert last_response.not_found?
  end
  
  it "should let you specify a :uri_template_style of :hex (the default tested above) or :plain" do
    set_up_repo(:uri_template_style => :plain)
    # todo: have it to_i the ID when it sees the type is :integer
    @repo.expects(:get_by_id).with('123').returns(TestModelFromRepo.new(:id => 123, :foo => 2, :bar => 1))
    get '/repo/123'
    assert_equal({
      "_tag"    => "/types/test-model-from-repo",
      "version" => "main",
      "id"      => 123,
      "foo"     => 2,
      "bar"     => 1,
    }, last_response.json)
  end
end
