// MiniRacer globals shim
// These globals are referenced at module init time by React's streaming
// build (bundled alongside renderToString) but not actually used by
// renderToString itself. They only need to exist, not be functional.
globalThis.TextEncoder = globalThis.TextEncoder || function () {
  this.encode = function (s) { return new Uint8Array(0) }
  this.encodeInto = function (s, d) { return { read: 0, written: 0 } }
}
globalThis.TextDecoder = globalThis.TextDecoder || function () {
  this.decode = function () { return '' }
}
globalThis.queueMicrotask = globalThis.queueMicrotask || function (cb) { Promise.resolve().then(cb) }
globalThis.crypto = globalThis.crypto || {}
globalThis.navigator = globalThis.navigator || { language: 'en-us' }
globalThis.MessageChannel = globalThis.MessageChannel || function () {
  this.port1 = { postMessage() {} }
  this.port2 = { addEventListener() {}, removeEventListener() {} }
}
