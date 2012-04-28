require 'rubygems'
require 'rack/test'
require 'test/spec'

require 'resource'

# here so each test does not have to declare one
TEST_REGISTRY = Typisch::Registry.new

module WirerHelpers

  def new_container(&block)
    @ctr = Wirer::Container.new
    @ctr.add(:resource_application_context, Resource::ApplicationContext)
    @ctr.add(:type_index, Resource::TypeIndex, '/types')
    @ctr.add_instance(TEST_REGISTRY)

    yield @ctr if block_given?

    @ctr
  end

end

# monkey patch some useful bits
class Rack::MockResponse

  def json
    @json ||= begin
      raise "MockResponse#json: expected json media_type" unless media_type =~ /^application\/.*json$/
      JSON.parse("[#{body}]")[0]
    end
  end

  # Useful to have these helpers in MockResponse corresponding to those in request:

  def media_type
    content_type && content_type.split(/\s*[;,]\s*/, 2)[0].downcase
  end

  def media_type_params
    return {} if content_type.nil?
    content_type.split(/\s*[;,]\s*/)[1..-1].
      collect { |s| s.split('=', 2) }.
      inject({}) { |hash,(k,v)| hash[k.downcase] = v ; hash }
  end

  def content_charset
    media_type_params['charset']
  end
end

module ResourceTestHelpers
  include Rack::Test::Methods

  def app(options={})
    @app ||= begin
      root = root_resource or raise "ResourceTestHelpers: set self.root_resource before running any requests"
      Doze::Application.new(root, {
        :catch_application_errors => false,
        :media_type_extensions => true,
        :logger => $stderr
      }.merge(options))
    end
  end

  attr_accessor :root_resource

end
