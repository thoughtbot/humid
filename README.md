# Humid
[![Build
Status](https://circleci.com/gh/thoughtbot/humid.svg?style=shield)](https://circleci.com/gh/thoughtbot/humid)

Humid is a lightweight wrapper around [mini_racer] and [webpacker] used to
generate Server Side Rendered (SSR) pages from your javascript application.
While it was built for React, it can work with any JS function that returns a
HTML string.

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

Add an initializer to configure

```ruby
Humid.configure do |config|
  # name of your webpacker pack. Defaults to "server_rendering.js"
  config.server_rendering_source = "server_rendering.js"

  # name of your webpacker pack source map. Defaults to `false`
  config.use_source_map = true

  # The logger instance. Defaults to `Logger.new(STDOUT)`
  # `console.log` and friends (`warn`, `error`) are delegated to
  # the respective logger levels on the ruby side.
  config.logger = Rails.logger

  # context_options. Options passed to mini_racer. Defaults to
  # empty.
  # config.context_options = {}
  config.context_options = {
    timeout: 1000,
    ensure_gc_after_idle: 2000
  }
end

# Common development options
if Rails.env.development?
  # Use single_threaded mode for Spring and other forked envs.
  MiniRacer::Platform.set_flags! :single_threaded

  # If you're using Puma in single mode:
  Humid.create_context
end
```

If you'd like support for source map support, you will need to
1. Ensure `config.use_source_map` is set to `true`
2. Add the following to your `server_rendering.js` pack.

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

## The mini_racer environment.

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

### Webpacker
You may need webpacker to create aliases for server friendly libraries that can
not detect the `mini_racer` environment.

```diff
 // config/webpack/development.js

 process.env.NODE_ENV = process.env.NODE_ENV || 'development'

 const environment = require('./environment')
+const path = require('path')
+const ConfigObject = require('@rails/webpacker/package/config_types/config

-module.exports = environment.toWebpackConfig()
+const webConfig = environment.toWebpackConfig()
+const ssrConfig = new ConfigObject(webConfig.toObject())
+
+ssrConfig.delete('entry')
+ssrConfig.merge({
+  entry: {
+    server_rendering: webConfig.entry.server_rendering
+  },
+  resolve: {
+    alias: {
+      'html-dom-parser': path.resolve(__dirname, '../../node_modules/html-dom-parser/lib/html-to-dom-server')
+    }
+  }
+})
+
+delete webConfig.entry.server_rendering
+module.exports = [ssrConfig, webConfig]
```

## Usage

Pass your HTML render function to `setHumidRenderer`

```javascript
setHumidRenderer((json) => {
  const initialState = JSON.parse(json)
  return ReactDOMServer.renderToString(
    <Application initialPage={initialState}/>
  )
})
```

And finally call `render` from ERB.

```ruby
<%= Humid.render(initial_state) %>
```

Instrumentation is included:

```
Completed 200 OK in 14ms (Views: 0.2ms | Humid SSR: 11.0ms | ActiveRecord: 2.7ms)
```

### Puma

`mini_racer` is thread safe, but not fork safe. To use with web servers that
employ forking, use `Humid.create_context` only on forked processes.

```ruby
# Puma
on_worker_boot do
  Humid.create_context
end

on_worker_shutdown do
  Humid.dispose
end
```

## Contributing

Please see [CONTRIBUTING.md](/CONTRIBUTING.md).

## License

Humid is Copyright © 2021-2021 Johny Ho.
It is free software, and may be redistributed under the terms specified in the
[LICENSE](/LICENSE.md) file.

## About thoughtbot

![thoughtbot](https://thoughtbot.com/brand_assets/93:44.svg)

Humid is maintained and funded by thoughtbot, inc.
The names and logos for thoughtbot are trademarks of thoughtbot, inc.

We love open source software!
See [our other projects][community] or
[hire us][hire] to design, develop, and grow your product.

[community]: https://thoughtbot.com/community?utm_source=github
[hire]: https://thoughtbot.com?utm_source=github
[mini_racer]: https://github.com/rubyjs/mini_racer
[webpacker]: https://github.com/rails/webpacker
