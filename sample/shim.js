export { TextEncoder, TextDecoder } from 'text-encoding'
export { URL, URLSearchParams } from 'whatwg-url'

export function MessageChannel() {
  this.port1 = {
    postMessage: function (message) {
      console.log('Message sent from port1:', message)
    },
  }

  this.port2 = {
    addEventListener: function (event, handler) {
      console.log(`Event listener added for ${event} on port2`)
      this._eventHandler = handler
    },
    removeEventListener: function (event) {
      console.log(`Event listener removed for ${event} on port2`)
      this._eventHandler = null
    },
    simulateMessage: function (data) {
      if (this._eventHandler) {
        this._eventHandler({ data })
      }
    },
  }
}

export const navigator = { language: 'en-us' }
