import * as esbuild from 'esbuild'
import { polyfillNode } from 'esbuild-plugin-polyfill-node'

await esbuild.build({
  entryPoints: ['app/javascript/server_rendering.tsx'],
  bundle: true,
  platform: 'browser',
  sourcemap: true,
  outfile: 'app/assets/builds/server_rendering.js',
  logLevel: 'info',
  loader: {
    '.svg': 'dataurl',
  },
  inject: ['./shim.js'],
  plugins: [
    polyfillNode({
      globals: false,
    }),
  ],
})
