module.exports = (env) ->

  events = require('events')

  class Device extends events.EventEmitter
    
    constructor: (opts) ->
      
      @debug = opts.debug
      @id = opts.id
      @name = opts.name
      @_host = opts.address
      @_xml = opts.xml
      @_type = opts.type
      
      @_player = null
    
    play: () -> @_inheritanceFailure('play()')
    stop: () -> @_inheritanceFailure('stop()')
    
    getHost: () -> return @_host
    getXML: () -> return @_xml
    getType: () -> return @_type
    
    onError: (callback) => @on('error', callback)
    
    _inheritanceFailure: (method) -> throw new Error( __("Children of Device class must implement %s", method) )
    _debug: (msg) -> env.logger.debug __("[%s] %s", @constructor.name, msg) if @debug

  return Device