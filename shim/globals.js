import { TextEncoder, TextDecoder } from 'text-encoding'

globalThis.TextEncoder = TextEncoder
globalThis.TextDecoder = TextDecoder
globalThis.MessageChannel = function () {
  this.port1 = { postMessage: function() {} }
  this.port2 = { addEventListener: function() {}, removeEventListener: function() {} }
}
globalThis.navigator = { language: 'en-us' }

require("source-map-support").install({
  retrieveSourceMap: (filename) => {
    if (typeof readSourceMap === 'function') {
      return { url: filename, map: readSourceMap(filename) }
    }
    return null
  }
})
