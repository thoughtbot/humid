const PnpWebpackPlugin = require(`pnp-webpack-plugin`);
const NodePolyfillPlugin = require('node-polyfill-webpack-plugin');
const path = require('path');
const webpack = require("webpack")

module.exports = {
  entry: {
    reporting: './spec/testapp/app/assets/javascript/reporting.js',
  },
  mode: "production",
  devtool: "source-map",
  resolve: {
    fallback: { 'fs': false },
  },
  resolveLoader: {
    modules: ['node_modules'],
  },
  output: {
    filename: "[name].js",
    sourceMapFilename: "[file].map",
    path: path.resolve(__dirname, 'spec/testapp/app/assets/builds'),
  },
  plugins: [
      new NodePolyfillPlugin()
  ]
};
