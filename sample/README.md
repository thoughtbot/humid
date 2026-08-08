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
2. `shim.js` — pre-built globals for MiniRacer's bare V8 (TextEncoder, URL, MessageChannel, etc.). Generated from `../shim/` — run `cd ../shim && npm install && npm run build` to rebuild.
3. `build.mjs` — esbuild bundles `app.jsx` into `build/app.js`
4. `render.rb` — configures Humid with `prepend: shim.js`, prepares a MiniRacer context, and calls `Humid.render` with JSON props
