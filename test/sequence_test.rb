require 'test/helpers'
require 'ostruct'

class TestDataClass < OpenStruct; end

TEST_REGISTRY.register do
  register :test_sequence, sequence(:integer)
end

describe "A Resourced::Sequence resource serializing some typed sequence data and making available range subresources" do
  include ResourcedTestHelpers
  include WirerHelpers

  def setup_sequence(options={})
    @ctr = new_container

    @resource = Resourced::Sequence.new(
      '/under_test',
      [0,1,2,3,4],
      TEST_REGISTRY[:test_sequence],
      @ctr.resource_application_context,
      options
    )

    self.root_resource = Class.new {include Doze::Router}.new
    root_resource.add_route('/under_test', :to => @resource)
  end

  it "should serialize the full sequence at /range/all" do
    setup_sequence
    get '/under_test/range/all'
    assert_equal [0,1,2,3,4], last_response.json
  end

  it "should expose range-based slices of the full sequence at /range/{begin}-{end}" do
    setup_sequence
    get '/under_test/range/0-0'
    assert_equal({"items"=>[0], "range_start"=>0, "_tag"=>"array", "total_items"=>5}, last_response.json)
    get '/under_test/range/0-1'
    assert_equal({"items"=>[0,1], "range_start"=>0, "_tag"=>"array", "total_items"=>5}, last_response.json)
    get '/under_test/range/1-2'
    assert_equal({"items"=>[1,2], "range_start"=>1, "_tag"=>"array", "total_items"=>5}, last_response.json)
    get '/under_test/range/3-5'
    assert_equal({"items"=>[3,4], "range_start"=>3, "_tag"=>"array", "total_items"=>5}, last_response.json)
    get '/under_test/range/5-6'
    assert_equal({"items"=>[], "range_start"=>5, "_tag"=>"array", "total_items"=>5}, last_response.json)
    get '/under_test/range/6-7'
    assert_equal({"range_start"=>6, "_tag"=>"array", "total_items"=>5}, last_response.json)
  end

  it "should let you configure a :max_length beyond which 'range' and 'all' requests will be 404'd" do
    setup_sequence(:max_length => 2)
    get '/under_test/range/0-1'
    assert_equal({"items"=>[0,1], "range_start"=>0, "_tag"=>"array", "total_items"=>5}, last_response.json)
    get '/under_test/range/0-2'
    assert last_response.not_found?

    get '/under_test/range/1-2'
    assert_equal({"items"=>[1,2], "range_start"=>1, "_tag"=>"array", "total_items"=>5}, last_response.json)
    get '/under_test/range/1-3'
    assert last_response.not_found?

    get '/under_test/range/all'
    assert last_response.not_found?
  end

end
