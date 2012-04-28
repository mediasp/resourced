require 'test/helpers'
require 'persistence/interfaces'
require 'mocha'

describe "A scenario using Resource::Object::WrappedModel resources wrapping underlying model classes, exposed via multiple repository resources routed to via a RepositoriesIndex" do

  class TestModel1 < ThinModels::Struct::Typed
    register_type TEST_REGISTRY do
      property :id, :integer
      property :exposed, :integer
      property :not_exposed, :integer
    end
    identity_attribute :id
  end

  class TestModel2 < ThinModels::Struct::Typed
    register_type TEST_REGISTRY do
      property :id, :integer
      property :foo, nullable(:TestModel1)
      property :foos, sequence(:TestModel1)
    end
    identity_attribute :id
  end

  class TestWrappedModel1 < Resource::Object
    include Resource::Object::WrappedModel

    wrap_model_class(TestModel1, TEST_REGISTRY) do
      expose :id, :exposed
      property :extra, :integer
    end

    def extra
      exposed + 100
    end
  end

  class TestWrappedModel2 < Resource::Object
    include Resource::Object::WrappedModel

    wrap_model_class(TestModel2, TEST_REGISTRY) do
      expose :id
      expose_wrapped_as_resource :foo
      expose_wrapped_as_resources :foos
    end
  end

  class TestModel1Repo
    include Persistence::IdentitySetRepository
    def self.model_class; TestModel1; end
  end

  class TestModel2Repo
    include Persistence::IdentitySetRepository
    def self.model_class; TestModel2; end
  end

  class TestRepoIndex < Resource::RepositoriesIndex
    expose_repository :test_model_1_repo, TestModel1Repo, TestWrappedModel1, '/wm1'
    expose_repository :test_model_2_repo, TestModel2Repo, TestWrappedModel2, '/wm2'
  end

  include ResourceTestHelpers
  include WirerHelpers

  def setup
    @ctr = new_container do |ctr|
      ctr.add_instance({
        TestWrappedModel1 => 'test-wrapped-model-1',
        TestWrappedModel2 => 'test-wrapped-model-2'
      }, :features => [:classes_exposed_as_type_resources])
      ctr.add :test_repo_index, TestRepoIndex, '/repo_index'
      ctr.add :test_model_1_repo, TestModel1Repo
      ctr.add :test_model_2_repo, TestModel2Repo
    end

    self.root_resource = Class.new {include Doze::Router}.new
    root_resource.add_route('/types', :to => @ctr.type_index)
    root_resource.add_route('/repo_index', :to => @ctr.test_repo_index)
  end

  it "should serialize properties from the underlying model which are expose'd in the wrap_model_class dsl block, and any extra typed property methods declared on the wrapping resource class, but not properties from the model which aren't exposed" do
    model1 = TestModel1.new(:id => 0xbeef, :exposed => 1, :not_exposed => 2)
    @ctr.test_model_1_repo.expects(:get_by_id).with(0xbeef).returns(model1)
    get '/repo_index/wm1/00/00/be/ef'
    assert_equal({
      "uri"     => "/repo_index/wm1/00/00/be/ef",
      "_tag"    => "/types/test-wrapped-model-1",
      "version" => "main",
      "id"      => 48879,
      "exposed" => 1,
      "extra"   => 101
     }, last_response.json)
     assert !last_response.json.has_key?('not_exposed')
  end

  it "should when a property is expose_wrapped_as_resource(s), automatically wrap the model instance(s) at that property in their own WrappedModel resource class instances, using the config for repository resources made available via a RepositoryIndex" do
    model1 = TestModel1.new(:id => 0xbeef, :exposed => 1, :not_exposed => 2)
    model2 = TestModel2.new(:id => 0xdead, :foo => model1, :foos => [model1])
    @ctr.test_model_2_repo.expects(:get_by_id).with(0xdead).returns(model2)
    get '/repo_index/wm2/00/00/de/ad'
    assert_equal({
      "uri"     => "/repo_index/wm2/00/00/de/ad",
      "_tag"    => "/types/test-wrapped-model-2",
      "version" => "main",
      "id"      => 57005,
      "foos"    => [{
        "exposed" => 1,
        "uri"     => "/repo_index/wm1/00/00/be/ef",
        "_tag"    => "/types/test-wrapped-model-1",
        "id"      => 48879,
        "version" => "main",
        "extra"   => 101
      }],
      "foo" => {
        "exposed" => 1,
        "uri"     => "/repo_index/wm1/00/00/be/ef",
        "_tag"    => "/types/test-wrapped-model-1",
        "id"      => 48879,
        "version" => "main",
        "extra"   => 101
      }
     }, last_response.json)
  end

end
