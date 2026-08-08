# Humid Shim

Pre-built JavaScript shim for MiniRacer's bare V8 environment. Provides globals that V8 doesn't have but SSR code expects.

## What it provides

- **TextEncoder / TextDecoder** — from `text-encoding` (real implementation, not stubs)
- **URL / URLSearchParams** — from `whatwg-url`
- **MessageChannel** — stub (React scheduler references it)
- **navigator** — stub with `language: 'en-us'`
- **source-map-support** — rewrites stack traces using source maps

## Building

```sh
npm install
npm run build
```

Outputs `dist/shim.js` — a self-contained CJS file with no external dependencies.

## How it works

Two-stage build with esbuild:

1. `globals.js` is built with `esbuild-plugin-polyfill-node` (for source-map-support's `path`/`fs` imports). Sets `globalThis.TextEncoder` etc.
2. `url.js` is built with the globals output as a banner. This ensures `TextEncoder` is available when `whatwg-url` initializes (it uses `TextEncoder` at module init time).

## Usage

Configure `prepend` in your Humid initializer:

```ruby
Humid.configure do |config|
  config.prepend = Rails.root.join("path/to/shim.js")
  config.application_path = Rails.root.join("app/assets/builds/server_rendering.js")
end

ctx = MiniRacer::Context.new
Humid.prepare(ctx)  # evals shim first, then the SSR bundle
```
