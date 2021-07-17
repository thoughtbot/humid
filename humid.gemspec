$LOAD_PATH << File.expand_path("lib", __dir__)
require "humid/version"

Gem::Specification.new do |s|
  s.name = "humid"
  s.version = Humid::VERSION
  s.author = "Johny Ho"
  s.email = "jho406@gmail.com"
  s.license = "MIT"
  s.homepage = "https://github.com/thoughtbot/humid/"
  s.summary = "Javascript SSR rendering for Rails"
  s.description = s.summary
  s.files = Dir["MIT-LICENSE", "README.md", "lib/**/*"]
  s.test_files = Dir["spec/*"]

  s.add_dependency "webpacker", ">= 4.0"
  s.add_dependency "mini_racer", ">= 0.4"
  s.add_dependency "activesupport", ">= 6.0"

  s.add_development_dependency "rake", " ~> 12.0"
  s.add_development_dependency "rspec", " ~> 3.8"
  s.add_development_dependency "byebug", "~> 9.0"
  s.add_development_dependency "rails", ">= 6.0"
end
