module Resourced
  # this is something which is *only* a router and doesn't serialize any additional data.
  #
  # use Resourced::Base together with Doze::Router if you want something which has
  # serialized data to also be a router
  module Router
    include Doze::Resource
    include Doze::Router

    def self.included(klass)
      super
      Doze::Router.included(klass)
    end

    def get
      [
        Doze::Serialization::JSON.entity_class.new(Base::JSON_MEDIA_TYPE, :encoding => 'utf-8') do
          Serializer::JsonableResourced.jsonable_routes(self)
        end,
        Doze::Entity.new(Base::HTML_MEDIA_TYPE, :encoding => 'utf-8') do
          Serializer::HTMLResourced.router_links_html(self)
        end
      ]
    end

  end
end
