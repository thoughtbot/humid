# Humid Sample

A minimal example of server-side rendering React with Humid and MiniRacer.

## Setup

```sh
npm install
bundle install
npm run build
```

## Run

```sh
bundle exec ruby render.rb World
# => <h1>Hello <!-- -->World</h1>

bundle exec ruby render.rb Superglue
# => <h1>Hello <!-- -->Superglue</h1>
```

## How it works

1. `app.jsx` — a React component and a `setHumidRenderer` call that renders it to HTML
2. `shim.js` — stubs for browser/Node globals that MiniRacer's V8 doesn't have
3. `build.mjs` — esbuild bundles `app.jsx` with the shim into `build/app.js`
4. `render.rb` — configures Humid, prepares a MiniRacer context, and calls `Humid.render` with JSON props
