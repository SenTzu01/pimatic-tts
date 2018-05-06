module.exports = (env) ->
  
  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  events = require('events')
  http = require('http')
  commons = require('pimatic-plugin-commons')(env)
  Browser = require('./SSDPBrowser')(env)
  
  class MediaPlayerDiscovery extends events.EventEmitter
    
    constructor: (@_browseInterval, @_browseDuration, @port, @debug = false) ->
      @base = commons.base @, 'MediaPlayerDiscovery'
      
      @base.error __("Instance creation failed. _browseInterval and _browseDuration parameters must be passed to the constructor") if !@_browseInterval? or !@_browseDuration?
      
      @_browser = null
      @_timerStartBrowser = null
      @_timerStopBrowser = null
      
    destroy: () ->
      clearTimeout @_timerStartBrowser if @_timerStartBrowser?
      clearTimeout @_timerStopBrowser if @_timerStopBrowser?
      @_stopBrowser()
    
    start: () -> @_startBrowser()
      
    stop: () ->
      @base.debug _("Stopping SSDP discovery due to external instruction")
      clearTimeout @_timerStartBrowser if @_timerStartBrowser?
      clearTimeout @_timerStopBrowser if @_timerStopBrowser?
      @_stopBrowser()
    
    _deviceFound: (device) => 
      
    _stopBrowser: () =>
      if @_browser?
        @_browser.destroy()
        @_browser = null
      
      @base.debug __("Media player discovery stopped")
      @emit('discoveryStopped', true)
    
    _startBrowser: () =>
      @base.debug "Media player discovery started"
        
      @_browser = new Browser(@port, @debug) # @debug
      @_browser.on( 'deviceFound', (device) => @emit('deviceDiscovered', device) )
      @_browser.start()
      @emit('discoveryStarted', true)
      
      @_timerStopBrowser = setTimeout(@_stopBrowser, @_browseDuration)
      @_timerStartBrowser = setTimeout(@_startBrowser, @_browseInterval)

  return MediaPlayerDiscovery