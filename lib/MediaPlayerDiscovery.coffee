module.exports = (env) ->
  
  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  events = require('events')
  http = require('http')
  commons = require('pimatic-plugin-commons')(env)
  Browser = require('./SSDPBrowser')(env)
  
  class MediaPlayerDiscovery extends events.EventEmitter
    
    constructor: (@_browseInterval, @_browseDuration, @debug = false) ->
      super()
      
      @base = commons.base @, 'MediaPlayerDiscovery'
      
      @_browseInterval ?= 30 *1000
      @_browseDuration ?= 10 *1000
      
      @_timerStartBrowser = null
      @_timerStopBrowser = null
      
      @_browser = null
      
    destroy: () ->
      @_stopBrowser()
      
      @removeAllListeners('start')
      @removeAllListeners('stop')
      @removeAllListeners('device')
    
    start: () -> @_startBrowser()
    stop: () -> @_stopBrowser()
    
    _foundDevice: (device) =>
      @base.debug __("Media player discovered: %s, configuring and emitting config", device.getName() )
      
      device.id = @_createDeviceId(device)
      device.name = @_safeString(device.getName(), ' ')
      
      env.logger.debug device
      @emit('new', device)
      
    _stopBrowser: () =>
        @base.debug __("Media player discovery stopped")
        
        clearTimeout @_timerStartBrowser if @_timerStartBrowser?
        clearTimeout @_timerStopBrowser if @_timerStopBrowser?
        
        if @_browser?
          @_browser.destroy()
          @_browser = null
        @emit('stop', true)
    
    _startBrowser: () =>
        @base.debug "Media player discovery started"
        
        @_browser = new Browser()
        @_browser.onDevice(@_foundDevice)
        @_browser.start()
        @emit('start', true)
        
        @_timerStartBrowser = setTimeout(@_startBrowser, @_browseInterval)
        @_timerStopBrowser = setTimeout(@_stopBrowser, @_browseDuration)
    
    _safeString: (string, char) => return string.replace(/(^[\W]|[\W]$)/g, '').replace(/[\W]+/g, char)
    _createDeviceId: (device) => return __("%s-%s", device.getType(), @_safeString(device.getName(), '-').toLowerCase() )
    
  return MediaPlayerDiscovery