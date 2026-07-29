import * as esbuild from 'esbuild'

await esbuild.build({
  entryPoints: ['app.jsx'],
  bundle: true,
  platform: 'browser',
  outfile: 'build/app.js',
  inject: ['./shim.js'],
  logLevel: 'info',
})
