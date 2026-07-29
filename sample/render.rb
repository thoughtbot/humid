require "bundler/setup"
require "json"
require "humid"

greeting = ARGV[0] || "World"

Humid.configure do |config|
  config.application_path = File.expand_path("build/app.js", __dir__)
  config.raise_render_errors = true
end

ctx = MiniRacer::Context.new
Humid.prepare(ctx)

props = JSON.generate({ name: greeting })
html = Humid.render(ctx, props)

puts html
