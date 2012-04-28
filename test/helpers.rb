require 'rubygems'
require 'rack/test'
require 'test/spec'

require 'resource'

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

  def resource_subclass(*mixins, &block)
    mixins << MSP::Resource::Base if mixins.empty?
    superclass = mixins.first.is_a?(Class) ? mixins.shift : Object
    Class.new(superclass) do
      mixins.each {|m| include m}
      class_eval(&block) if block
    end
  end

  def mock_resource(*mixins, &block)
    resource_subclass(*mixins, &block).new
  end

  def set_mock_root_resource(*m, &b)
    self.root_resource = mock_resource(*m, &b)
  end

  def expand_template(template, vars)
    Doze::URITemplate.compile(template).expand(vars)
  end

  # We don't want registered media types to persist beyond the particular test run
  def setup
    @media_type_name_lookup = Doze::MediaType::NAME_LOOKUP.dup
    super
  end

  def teardown
    super
    Doze::MediaType::NAME_LOOKUP.replace(@media_type_name_lookup || {})
  end
end
