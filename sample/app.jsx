import React from 'react'
import { renderToString } from 'react-dom/server'

const Greeting = ({ name }) => <h1>Hello {name}</h1>

setHumidRenderer((json) => {
  const props = JSON.parse(json)
  return renderToString(<Greeting {...props} />)
})
