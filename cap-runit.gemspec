Gem::Specification.new do |gem|
  gem.name = 'cap-runit'
  gem.version = '0.2.1'

  gem.summary = 'Capistrano 3 Runit integration'
  gem.description = "Template for managing runit directories with capistrano 3"

  gem.authors = ['Conrad Irwin']
  gem.email = %w(conrad@bugsnag.com)
  gem.homepage = 'http://github.com/ConradIrwin/cap-runit'

  gem.license = 'MIT'

  gem.add_dependency 'capistrano', '>= 3.0'

  gem.files = `git ls-files`.split("\n")
end
