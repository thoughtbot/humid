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

  s.add_dependency "mini_racer", ">= 0.4"
  s.add_dependency "activesupport", ">= 7.0"
end
