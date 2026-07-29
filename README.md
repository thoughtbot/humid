<div align="center">
  <img src="./images/svg/humid-icon.svg" alt="Humid" width="128" />
  <h1>Humid</h1>
  ![Build Status](https://github.com/thoughtbot/humid/actions/workflows/build.yml/badge.svg?branch=main)
</div>

Humid is a set of helper functions for using `mini_racer` for Server Side
Rendering (SSR). **There are only 2 pure public functions and a `configure` to set
default args**. `mini_racer` does the heavy lifting, Humid just provides a few
conveniences.

While it was built with React in mind, it can work with any JS function that
returns an HTML string.

## Design

Humid is designed with 2 goals in mind:

1. Its for the common case where all data is gathered before rendering. Your
application fetches everything needed, passes it as props, and Humid returns
the rendered HTML in a single synchronous call. It does not support streaming
or async data fetching during render.

2. Its a stepping stone for when you want to scale on the edge using
[Cloudflare V8 isolates](https://developers.cloudflare.com/workers/reference/how-workers-works/)
.`mini_racer` is a bare V8 environment, if your JS bundle works with
`mini_racer`, it'll work on Cloudflare V8 isolates.

## Caution

This project is in its early phases of development. Its interface,
behavior, and name are likely to change drastically before a major version
release.

## Installation

Add Humid to your Gemfile.

```
gem 'humid'
```

For source-map support, also add

```
yarn add source-map-support
```

## Configuration

Add an initializer to configure the default options for `Humid.render`. These
are overridable on `Humid.render`.

```ruby
# config/initializers/humid.rb

Humid.configure do |config|
  # Path to your build file located in `app/assets/builds/`. You should use a
  # separate build apart from your `application.js`.
  #
  # Required
  config.application_path = Rails.root.join("app/assets/builds/server_rendering.js")

  # Path to your source map file
  #
  # Optional
  config.source_map_path = Rails.root.join("app/assets/builds/server_rendering.js.map")

  # Raise errors if JS rendering failed. If false, the error will be
  # logged and Humid.render will return an empty string.
  #
  # Defaults to true.
  config.raise_render_errors = Rails.env.local?

  # The logger instance.
  # `console.log` and friends (`warn`, `error`) are delegated to
  # the respective logger levels on the ruby side.
  #
  # Defaults to `nil`
  config.logger = Rails.env.local? ? Rails.logger : nil
end

if Rails.env.local?
  # Use single_threaded mode for dev and test environments.
  # This will also work for mini_test parallel tests
  MiniRacer::Platform.set_flags! :single_threaded
  MINI_RACER_SSR = { context: MiniRacer::Context.new(timeout: 1000, ensure_gc_after_idle: 2000) }

  # Reload the context when the SSR bundle changes
  ssr_checker = ActiveSupport::FileUpdateChecker.new([Humid.config.application_path.to_s]) do
    MINI_RACER_SSR[:context].dispose
    MINI_RACER_SSR[:context] = MiniRacer::Context.new(timeout: 1000, ensure_gc_after_idle: 2000)
  end

  Rails.application.reloaders << ssr_checker
  Rails.application.reloader.to_run do
    ssr_checker.execute_if_updated
  end
end
```

## Usage

### Set a renderer

In your entry file, e.g, `server_rendering.js` (specified in
`config.application_path`), pass your HTML render function to
`setHumidRenderer`. There is no need to require the function, its included in
the environment.

```javascript
// Set a factory function that will create a new instance of our app
// for each request.
setHumidRenderer((json) => {
  const initialState = JSON.parse(json)

  return ReactDOMServer.renderToString(
    <Application initialPage={initialState}/>
  )
})
```

If you'd like support for source map support, you will need to add the following
to the same file and set `config.source_map_path` like the configuration above.

```javascript
require("source-map-support").install({
  retrieveSourceMap: filename => {
    return {
      url: filename,
      map: readSourceMap(filename)
    };
  }
});
```

### Your webserver

On production, keep in mind that `mini_racer` is **thread safe, but not fork
safe**. When using with web servers that employ forking, create the context
on worker boot. **There should be no context created on the master process.**

For example with puma:

```ruby
# config/puma.rb
on_worker_boot do
  ctx = MiniRacer::Context.new(timeout: 1000, ensure_gc_after_idle: 2000)
  MINI_RACER_SSR = { context: Humid.prepare(ctx) }
end

on_worker_shutdown do
  MINI_RACER_SSR[:context].dispose
end
```

`Humid.prepare` will prepare the context's
[environment](#the-mini_racer-environment).

You can also override config options per-context:

```ruby
ctx = Humid.prepare(
  MiniRacer::Context.new(timeout: 1000),
  application_path: Rails.root.join("other_bundle.js"),
  logger: nil
)
MINI_RACER_SSR = { context: ctx }
```

> [!NOTE]
> If you pass a context that was already prepared, `prepare` will noop and return the context back to you.

See the [sample server_rendering.tsx](./sample/server_rendering.tsx) to see how
it is integrated.

### Call `Humid.render`

And finally call `render` from ERB.

```ruby
<%= Humid.render(MINI_RACER_SSR[:context], json).html_safe %>
```

Instrumentation is included:

```
Completed 200 OK in 14ms (Views: 0.2ms | Humid SSR: 11.0ms | ActiveRecord: 2.7ms)
```

## The `mini_racer` environment

### Functions not available

The following functions are **not** available in the mini_racer environment

- `setTimeout`
- `clearTimeout`
- `setInterval`
- `clearInterval`
- `setImmediate`
- `clearImmediate`

### `console.log`

`console.log` and friends (`info`, `error`, `warn`) are delegated to the
respective methods on the configured logger.

All arguments are passed through — MiniRacer converts JS objects to Ruby
hashes and arrays automatically. A `log_formatter` proc controls how these
arguments are formatted into a single string for the logger:

```ruby
Humid.configure do |config|
  config.logger = Rails.logger

  config.log_formatter = proc { |level, message, *rest|
    parts = [message]
    parts += rest.map { |a| a.is_a?(String) ? a : JSON.pretty_generate(a) }
    parts.join("\n")
  }
end
```

The formatter receives `(level, message, *rest)` where:
- `level` — the log level as a symbol (`:debug`, `:info`, `:warn`, `:error`)
- `message` — the first argument passed to `console.log/info/warn/error`
- `rest` — any additional arguments (objects come through as Ruby hashes/arrays)

The default formatter returns `message` unchanged.

## Server-side libraries that detect node.js envs.

You may need webpacker to create aliases for server friendly libraries that can
not detect the `mini_racer` environment. For example, in `webpack.config.js`.

```diff
...
  resolve: {
    alias: {
      'html-dom-parser': path.resolve(__dirname, '../../node_modules/html-dom-parser/lib/html-to-dom-server')
    }
  }
...
```

## Writing universal code
[Vue has a resource][vue_ssr] on how to write universal code. Below
are a few highlights that are important to keep in mind.

## State

Humid uses a single context across multiple request. To avoid state pollution, we
provide a factory function to `setHumidRenderer` that builds a new app instance on
every call.

This provides better isolation, but as it is still a shared context, polluting
`global` is still possible. Be careful of modifying `global` in your code.

## Missing browser APIs

Some libraries that depend on browser APIs will fail in the
`mini_racer` environment because of missing browser APIs. Account for this by
moving the `require` to `useEffect` in your component.

```
  useEffect(() => {
    const svgPanZoom = require('svg-pan-zoom')
    //...
  }, [])
```

## Polyfills

React SSR may import node.js dependencies that you need to polyfill for. See
a sample esbuild [build script](./sample/bulid_ssr.js) and a [shim.js](./sample/shim.js)
to get around these issues.

## Telemetry

The `MiniRacer::Context` gives you access to V8 heap statistics for monitoring
memory usage over time.

```ruby
MINI_RACER_SSR[:context].heap_stats
# {:total_heap_size=>3100672,
#  :total_heap_size_executable=>4194304,
#  :total_physical_size=>1280640,
#  :total_available_size=>1501560832,
#  :used_heap_size=>1205376,
#  :heap_size_limit=>1501560832,
#  ...}
```

You can combine humid's instrumentation and OpenTelemetry to track heap growth
per worker:

```ruby
meter = OpenTelemetry.meter_provider.meter("humid")
render_histogram = meter.create_histogram("humid.render.duration", unit: "ms", description: "SSR render duration")
heap_gauge = meter.create_gauge("humid.heap.used_bytes", unit: "By", description: "V8 heap used bytes")

ActiveSupport::Notifications.subscribe("render.humid") do |event|
  stats = MINI_RACER_SSR[:context].heap_stats
  attributes = { "worker.pid" => Process.pid.to_s }

  render_histogram.record(event.duration, attributes: attributes)
  heap_gauge.record(stats[:used_heap_size], attributes: attributes)
end
```

A steadily climbing `used_heap_size` across requests indicates a memory leak in
your JavaScript bundle.


## Contributing

Please see [CONTRIBUTING.md](/CONTRIBUTING.md).

## License

Humid is Copyright © 2021-2024 Johny Ho.
It is free software, and may be redistributed under the terms specified in the
[LICENSE](/LICENSE.md) file.

<!-- START /templates/footer.md -->
## About thoughtbot

![thoughtbot](https://thoughtbot.com/thoughtbot-logo-for-readmes.svg)

This repo is maintained and funded by thoughtbot, inc.
The names and logos for thoughtbot are trademarks of thoughtbot, inc.

We love open source software!
See [our other projects][community].
We are [available for hire][hire].

[community]: https://thoughtbot.com/community?utm_source=github
[hire]: https://thoughtbot.com/hire-us?utm_source=github

<!-- END /templates/footer.md -->

[mini_racer]: https://github.com/rubyjs/mini_racer
[vue_ssr]: https://ssr.vuejs.org/
[sample]: ./webpack.config.js
