module Resourced
  class Sequence < SerializedWithType
    include Router

    def initialize(uri, data, type, application_context, options={})
      @uri = uri
      @data = data
      @type = type
      @application_context = application_context
      @max_length = options[:max_length]
    end

    attr_reader :max_length

    route "/range/{begin}-{end}", :name => 'range', :regexps => {:begin => /\d+/, :end => /\d+/} do |router, matched_uri, params|
      router.range_resource(matched_uri, params[:begin].to_i, params[:end].to_i)
    end

    route "/range/all", :name => 'all_items' do |router, matched_uri|
      router.all_items_resource(matched_uri)
    end

    def range_resource(uri, first, last)
      length = last-first+1
      if length >= 0 && (!max_length || length <= max_length)
        SerializedWithType.new(uri, @data, @type.with_options(:slice => first..last), @application_context)
      end
    end

    def all_items_resource(uri)
      SerializedWithType.new(uri, @data, @type.with_options(:slice => nil), @application_context) unless max_length
    end
  end
end
