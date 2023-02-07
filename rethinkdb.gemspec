
Gem::Specification.new do |s|
  s.name      = 'rethinkdb'
  s.version   = '2.5.0.0'
  s.summary   = 'This package provides the Ruby driver library for the RethinkDB database server.'
  s.author    = 'RethinkDB Inc.'
  s.email     = 'bugs@rethinkdb.com'
  s.homepage  = 'https://rethinkdb.com'
  s.license   = 'Apache-2.0'
  s.files     = Dir['lib/*.rb']

  s.required_ruby_version = '>= 2.7.7'

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'eventmachine'
end
