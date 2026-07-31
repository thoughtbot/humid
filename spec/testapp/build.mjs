import * as esbuild from 'esbuild'
import { polyfillNode } from 'esbuild-plugin-polyfill-node'

await esbuild.build({
  entryPoints: ['app/assets/javascript/reporting.js'],
  bundle: true,
  platform: 'browser',
  sourcemap: true,
  outfile: 'app/assets/builds/reporting.js',
  inject: ['./shim.js'],
  plugins: [
    polyfillNode({
      globals: false,
    }),
  ],
})
