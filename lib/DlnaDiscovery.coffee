module.exports = (env) ->
  
  commons = require('pimatic-plugin-commons')(env)
  Promise = env.require 'bluebird'
  DLNA = require 'dlnacasts'
  MediaRenderer = require 'upnp-mediarenderer-client'
  _ = env.require 'lodash'
  
  class DlnaDiscovery extends env.event.emitter
    
    constructor: (@_interval, @_duration) ->
      @_interval ?= 30 *1000
      @_duration ?= 10 *1000
      
      @_discoveryStartTimer = null
      @_discoveryStopTimer = null
      
      @_dlnaDeviceList = []
      @_dlnaBrowser = null
      
    destroy: () ->
      clearTimeout @_discoveryStartTimer
      clearTimeout @_discoveryStopTimer

      @_discoveryStartTimer = undefined
      @_discoveryStopTimer = undefined
      
      @_dlnaBrowser.removeListener('update', @_dlnaDeviceFound)
      @removeAllListeners('start')
      @removeAllListeners('stop')
      @removeAllListeners('device')
    
    start: () -> @_discoveryStart()
    stop: () -> @_discoveryStop
      
    _dlnaDeviceFound: (config) =>
      @base.debug __("DLNA device discovered: %s", config.name)
        
      config.id = @_createDeviceId(config.name)
      config.client = new MediaRenderer(config.xml)
      
      @emit('device', config)
      
    _discoveryStop: () =>
      @base.debug __("DLNA device discovery stopped")
      
      @_dlnaBrowser.removeListener('update', @_dlnaDeviceFound)
      @_dlnaBrowser = null
      @emit('stop', true)
        
    _discoveryStart: () =>
      @base.debug "DLNA device discovery started"
      
      @emit('start', true)
      
      dlnaBrowser = DLNA()
      dlnaBrowser.on('update', @_dlnaDeviceFound)
      
      @_discoveryStopTimer = setTimeout(@_discoveryStop, @_duration)
      @_discoveryStartTimer = setTimeout(@_discoveryStart, @_interval)
    
    _createDeviceId: (id) -> return 'dlna-' + id.replace(/(^[\W]|[\W]$)/g, '').replace(/[\W]+/g, '-').toLowerCase()
    
  return DlnaDiscovery