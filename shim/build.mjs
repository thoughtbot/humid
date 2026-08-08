import * as esbuild from 'esbuild'
import { polyfillNode } from 'esbuild-plugin-polyfill-node'
import { readFileSync } from 'fs'

// Step 1: Build globals shim (TextEncoder, MessageChannel, navigator,
// source-map-support) with Node polyfills for path/fs
await esbuild.build({
  entryPoints: ['./globals.js'],
  bundle: true,
  format: 'cjs',
  platform: 'browser',
  outfile: 'dist/globals.js',
  plugins: [polyfillNode({ globals: false })],
})

// Step 2: Build URL shim with globals prepended as banner.
// whatwg-url needs TextEncoder at module init time, so globals
// must run first. esbuild's banner truly prepends.
const globalsBanner = readFileSync('./dist/globals.js', 'utf8')

await esbuild.build({
  entryPoints: ['./url.js'],
  bundle: true,
  format: 'cjs',
  platform: 'browser',
  outfile: 'dist/shim.js',
  banner: { js: globalsBanner },
})

console.log('Built dist/shim.js')
