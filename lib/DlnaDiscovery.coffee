module.exports = (env) ->
  
  commons = require('pimatic-plugin-commons')(env)
  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  NodeCast = require 'nodecast-js'
  events = require('events')
  
  class DlnaDiscovery extends events.EventEmitter
    
    constructor: (@_interval, @_duration, @debug = false) ->
      @base = commons.base @, 'Plugin'
      
      @_interval ?= 30 *1000
      @_duration ?= 10 *1000
      
      @_discoveryStartTimer = null
      @_discoveryStopTimer = null
      
      @_dlnaBrowser = null
      
    destroy: () ->
      clearTimeout @_discoveryStartTimer
      clearTimeout @_discoveryStopTimer

      @_discoveryStop()
      
      @removeAllListeners('start')
      @removeAllListeners('stop')
      @removeAllListeners('device')
    
    start: () -> @_discoveryStart()
    
    stop: () -> 
      clearTimeout @_discoveryStartTimer
      clearTimeout @_discoveryStopTimer
      @_discoveryStop()
    
    _dlnaDeviceFound: (config) =>
      @base.debug __("DLNA device discovered: %s", config.name)
      
      config.id = @_createDeviceId(config.name)
      @emit('new', config)
      
    _discoveryStop: () =>
        @base.debug __("DLNA device discovery stopped")
        
        if @_dlnaBrowser?
          @_dlnaBrowser.destroy()
          @_dlnaBrowser = null
        @emit('stop', true)
        
    _discoveryStart: () =>
        @base.debug "DLNA device discovery started"
        
        @_dlnaBrowser = new NodeCast()
        @_dlnaBrowser.onDevice(@_dlnaDeviceFound)
        @_dlnaBrowser.start()
        @emit('start', true)
        
        @_discoveryStopTimer = setTimeout(@_discoveryStop, @_duration)
        @_discoveryStartTimer = setTimeout(@_discoveryStart, @_interval)
    
    _createDeviceId: (id) -> return 'dlna-' + id.replace(/(^[\W]|[\W]$)/g, '').replace(/[\W]+/g, '-').toLowerCase()
    
  return DlnaDiscovery