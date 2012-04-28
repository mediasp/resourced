# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'resource/version'

spec = Gem::Specification.new do |s|
  s.name   = "resource"
  s.version = Resource::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ['Matthew Willson', 'Nick Griffiths', 'MSP Development Team']
  s.email = ["matthew.willson@gmail.com", "nicobrevin@gmail.com", "dev@mediasp.com"]
  s.summary = "Resource library for building API applications"
  s.description = 'Brings together doze, persistence and wirer to provide conveniences for building REST API applications'
  s.homepage = 'http://dev.playlouder.com'


  # this is a dependency of savon, but we needed to patch a bug in it,
  # so freezing to the version which the patch applies to.
  s.add_dependency('wirer')
  s.add_dependency('persistence')
  s.add_dependency('doze')
  s.add_dependency('typisch')

  s.add_development_dependency('test-spec')
  s.add_development_dependency('rack-test')


  s.files = Dir.glob("lib/**/*.rb")
end