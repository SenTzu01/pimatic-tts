module.exports = (env) ->
  
  _ = env.require 'lodash'
  commons = require('pimatic-plugin-commons')(env)
  Promise = env.require 'bluebird'
  t = env.require('decl-api').types
  
  class DLNAPlayerDevice extends env.devices.PresenceSensor
    
    constructor: (@config, lastState, @_plugin) ->
      @id = @config.id
      @name = @config.name
      @debug = @_plugin.config.debug || false
      @base = commons.base @, "DLNAPlayerDevice"
      @_detected = false
      @_pauseUpdates = false
      @_device = lastState?.device?.value or null
      
      @_playerEvents = {
        loading: @_onPlayerEvent
        playing: @_onPlayerEvent
        paused: @_onPlayerEvent
        stopped: @_onPlayerEvent
        error: @_onPlayerEvent
      }
      
      @addAttribute('type',{
        description: "DLNA Type"
        type: t.string
        acronym: 'DLNA Type:'
        discrete: true})
            
      @addAttribute('host',{
        description: "Device network address"
        type: t.string
        acronym: 'Network address:'
        discrete: true})
        
      @addAction('startDlnaStreaming', {
        description: "Stream a media resource to the DLNA device"
        params:
          url:
            type: t.string
      })
      
      @addAction('playAudio', {
        description: "Stream a media resource to the DLNA device"
        params:
          resource:
            type: t.string
      })
      
      @addAction('stopDlnaStreaming', {
        description: "Stop playback on the DLNA Device"})
      
      @_plugin.on('discoveredMediaPlayer', @updateDevice)
      
      onDiscoveryEnd = () =>
        @_setPresence(false) if !@_detected
        @_detected = false
      @_plugin.on('discoveryEnd', onDiscoveryEnd)
      
      super()

    destroy: ->
      @_plugin.removeListener('discoveryEnd', onDiscoveryEnd)
      @_plugin.removeListener('discoveredMediaPlayer', @updateDevice)
      super()
      
    updateDevice: (device) =>
      return unless device.id is @id 
      @_setDevice(device)
      @_setPresence(true)
      @_detected = true
    
    _setPresence: (presence) ->
      return if presence is @_presence
      super(presence)
    
    _setDevice: (device) ->
      @base.debug __("Updating network device information")
      @_device = device unless @_pauseUpdates
      @_type = device.getType()
      @emit 'host', device.getHost()
      
      @emit 'type', device.getType()
      @emit('device', device)
    
    getDevice: () -> Promise.resolve(@_device)
    getType: () -> Promise.resolve(@_type or 'N/A')
    getHost: () -> Promise.resolve(@_host or '0.0.0.0')
      
    playAudio: (url) -> 
      return new Promise( (resolve, reject) =>
        @base.debug __("Starting audio output")
        
        @_pauseUpdates = true
        @_device.once( event, (data) => return handler(e, data) ) for event, handler of @_playerEvents
        
        play = @_device.play(url, 0)
        env.logger.debug @_device
      )
      .catch( (error) =>
        @base.resetLastError()
        @base.rejectWithErrorString Promise.reject, error
      )
      
    stopDlnaStreaming: () -> @_device.stop() if @_device? and @_presence
    
    _onPlayerEvent: (event, data) => 
      @base.debug __("Network media player: %s", event)
      if event is 'stopped'
        @_pauseUpdates = false
        return Promise.resolve event
      
      if event is 'error'
        @_pauseUpdates = false
        @base.resetLastError()
        return @base.rejectWithErrorString( Promise.reject, error, __("Media player error during playback of: %s", url) )
      
      return @emit(event, data)
  
  return DLNAPlayerDevice