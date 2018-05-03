module.exports = (env) ->

  events = require('events')

  class Device extends events.EventEmitter
    
    constructor: () ->
      super()
    
    play: () -> @_InheritanceFailure()
    
    stop: () -> @_InheritanceFailure()
    
    getName: () -> return @_name
    getHost: () -> return @_host
    getXML: () -> return @_xml
    getType: () -> return @_type
    
    onError: (callback) => @on('error', callback)
    
    _InheritanceFailure: () -> throw new Error('Not implemented')

  return Device