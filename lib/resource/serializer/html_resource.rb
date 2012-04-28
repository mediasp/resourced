require 'doze/utils'

module MSP::Resource2
  module Serializer; end

  class Serializer::HTMLResource < Typisch::Serializer
    include Serializer::Resource

    DEFAULT_TEMPLATE = File.join(File.dirname(__FILE__), 'template.html')
    def self.template(filename=nil)
      filename ||= DEFAULT_TEMPLATE
      @templates ||= {}
      @templates[filename] ||= File.read(filename)
    end

    def initialize(type, type_index, options={})
      super(type)
      @class_to_type_tag = options[:class_to_type_tag] || type_index.classes_to_uris
      @template = Serializer::HTMLResource.template(options[:template])
      @max_depth = options[:max_depth] || 15
      @type_index = type_index
      
      @compatibility_tag_key           = options[:compatibility_tag_key]
      @class_name_to_compatibility_tag = options[:class_name_to_compatibility_tag]
      @uri_key                         = options[:uri_key] || '_uri'
      @version_key                     = options[:version_key] || '_version'
      @type_tag_key                    = options[:type_tag_key] || '_tag'
      @version_as_uri                  = options[:version_as_uri] != false
    end

    def serialize(data, add_route_info_for=(data if Doze::Router === data))
      result = @template.dup
      result.sub!("<!--DATA-->", "<h1>Resource data</h1>\n#{serialize_type(data, @type)}") if @type
      if add_route_info_for
        header_links, html_links = self.class.make_router_links_html(add_route_info_for)
        result.sub!("<!--HEADER-->", header_links)
        result.sub!("<!--SUBRESOURCE_LINKS-->", html_links)
      end
      result
    end

    def self.router_links_html(router, template_filename=nil)
      result = template(template_filename).dup
      header_links, html_links = make_router_links_html(router)
      result.sub!("<!--HEADER-->", header_links)
      result.sub!("<!--SUBRESOURCE_LINKS-->", html_links)
      result
    end

  private

    def serialize_type(value, type, depth=0)
      raise Typisch::SerializationError, "exceeded max depth of #{@max_depth}" if depth > @max_depth
      super
    end

    def serialize_slice(value, type, depth)
      i=type.slice.begin-1
      items = value[type.slice].map do |v|
        self.class.make_table_row(i+=1, serialize_type(v, type.type, depth+1))
      end
      items << self.class.make_table_row("range_start", self.class.make_string_html(type.slice.begin))
      items << self.class.make_table_row("total_items", self.class.make_string_html(value.length)) if type.total_length
      
      if @compatibility_tag_key && (compat_tag = @class_name_to_compatibility_tag[value.class.to_s])
        items << self.class.make_table_row(@compatibility_tag_key, self.class.make_string_html(compat_tag))
      end

      "<table rules='all' frame='void'>#{items.join("\n")}</table>"
    end

    def serialize_sequence(value, type, depth)
      i=-1; items = value.map do |v|
        self.class.make_table_row(i+=1, serialize_type(v, type.type, depth+1))
      end
      items.length == 0 ? '&nbsp;' : "<table rules='all' frame='void'>#{items.join("\n")}</table>"
    end

    def serialize_map(value, type, depth)
      raise Typisch::SerializationError, "only supports string keys for maps" unless Typisch::Type::String === type.key_type
      pairs = value.map do |k,v|
        self.class.make_table_row(k, serialize_type(v, type.value_type, depth+1))
      end
      "<table rules='all' frame='void'>#{pairs.join("\n")}</table>"
    end

    def serialize_tuple(value, type, depth)
      i=-1; items = type.types.zip(value).map do |t,v|
        self.class.make_table_row(i+=1, serialize_type(v, t, depth+1))
      end
      "<table rules='all' frame='void'>#{items.join("\n")}</table>"
    end

    def serialize_object(value, type, depth)
      pairs = type.property_names_to_types.map do |prop_name,prop_type|
        v = serialize_type(value.send(prop_name), prop_type, depth+1)
        self.class.make_table_row(prop_name, v) unless @elide_null_properties && v.nil?
      end.compact
      if type.version
        version_html = if @version_as_uri
          version_uri = @type_index.type_resource_uri_for_class_and_version(value.class, type.version)
          self.class.make_link_html(version_uri)
        else
          self.class.make_string_html(type.version)
        end
        pairs.unshift self.class.make_table_row(@version_key, version_html)
      end
      tag = @class_to_type_tag[value.class]
      tag_html = tag =~ /^\// ? self.class.make_link_html(tag) : self.class.make_string_html(tag)
      pairs.unshift self.class.make_table_row(@type_tag_key, tag_html)
      
      if @compatibility_tag_key && (compat_tag = @class_name_to_compatibility_tag[value.class.to_s])
        pairs.unshift self.class.make_table_row(@compatibility_tag_key, self.class.make_string_html(compat_tag))
      end
      
      if Doze::Resource === value && (uri = value.uri)
        pairs.unshift self.class.make_table_row(@uri_key, self.class.make_link_html(uri))
      end
      "<table rules='all' frame='void'>#{pairs.join("\n")}</table>"
    end

    def serialize_value(value, *)
      self.class.make_string_html(value)
    end
    
    def self.make_table_row(key, value_html)
      "<tr><td>#{make_string_html(key)}</td><td>#{value_html}</td></tr>"
    end

    def self.make_link_html(uri)
      "<a href='#{escape(uri)}'>#{escape(uri)}</a>"
    end

    def self.make_uri_template_form(uri_template)
      return make_link_html(uri_template) if uri_template.variables.length == 0
      # Clever HTML rendering of a URI template.
      # Make a HTML form which uses some javascript onsubmit to navigate to an expanded version of the URI template,
      # with blanks filled in via INPUTs.
      inputs = uri_template.parts.map do |part|
        case part
        when Doze::URITemplate::String
          Rack::Utils.escape_html(part.string)
        when Doze::URITemplate::QuadHexBytesVariable
          "/<input name='#{escape(part.name)}'>"
        when Doze::URITemplate::Variable
          "<input name='#{escape(part.name)}'>"
        end
      end.join

      i=-1; js = uri_template.parts.map do |part|
        case part
        when Doze::URITemplate::String
          part.string.to_json
        when Doze::URITemplate::QuadHexBytesVariable
          i += 1; "(v = parseInt(this.elements[#{i}].value, '10').toString(16), (new Array(9-v.length).join('0')+v).replace(/(..)/g, '/$1'))"
        when Doze::URITemplate::Variable
          i += 1; "this.elements[#{i}].value"
        end
      end

      js = "window.location.href = #{js.join(" + ")}; return false"
      "<form method='GET' onsubmit='#{escape(js)}'>#{inputs}<input type='submit'></form>"
    end

    def self.make_string_html(data)
      string = data.to_s.strip
      string.empty? ? '&nbsp;' : "<span>#{escape(string)}</span>"
    end

    def self.escape(s)
      Rack::Utils.escape_html(s)
    end

    def self.make_router_links_html(router)
      header_links = []; html_links = []
      router.routes.each do |route|
        # For now we hold off exposing templates for the media-type-specific subresources on every separate resource,
        # since it adds a fair bit of redundancy
        next if route.name == 'specific_media_type'

        template = route.template(router.router_uri_prefix)
        header_links << "<link href='#{escape(template)}' rel='#{escape(route.name)}'>"
        html_links   << "<dt>#{escape(route.name)}</dt><dd>#{make_uri_template_form(template)}</dd>"
      end
      return header_links.join("\n"), "<h1>Subresource links</h1>\n<dl>\n#{html_links.join("\n")}\n</dl>"
    end
  end
end
