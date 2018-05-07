module.exports = (env) ->
  
  _ = env.require 'lodash'
  commons = require('pimatic-plugin-commons')(env)
  Promise = env.require 'bluebird'
  t = env.require('decl-api').types
  
  class MediaPlayerDevice extends env.devices.PresenceSensor
    
    constructor: (@config, lastState, @_plugin) ->
      @id = @config.id
      @name = @config.name
      
      @debug = @_plugin.config.debug || @config.debug || false
      @base = commons.base @, "MediaPlayerDevice"
      
      @_detected = false
      @_pauseUpdates = false
      @_device = lastState?.device?.value or null
      
      @addAttribute('type',{
        description: "Device type"
        type: t.string
        acronym: 'Device type:'
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
            type: t.string})
      
      @addAction('playAudio', {
        description: "Stream a media resource to the DLNA device"
        params:
          resource:
            type: t.string})
      
      @addAction('stopDlnaStreaming', {
        description: "Stop playback on the DLNA Device"})
      
      @_plugin.on('discoveredMediaPlayer', @updateDevice)
      @_plugin.on('discoveryEnd', @_onDiscoveryEnd)
      
      super()

    destroy: ->
      @_plugin.removeListener('discoveryEnd', @_onDiscoveryEnd)
      @_plugin.removeListener('discoveredMediaPlayer', @updateDevice)
      super()
    
    updateDevice: (device) =>
      return unless device.id is @id 
      @base.debug __("Updating network device information")
      @_detected = true

      if !@_pauseUpdates
        @_device = device
        
        @emit 'device', device
        @emit 'host', device.getHost()
        @emit 'type', device.getType()
      
      @_setPresence(true)
    
    getDevice: () -> Promise.resolve(@_device)
    getType: () -> Promise.resolve(@_device?.getType() or 'N/A')
    getHost: () -> Promise.resolve(@_device?.getHost() or '0.0.0.0')
      
    playAudio: (url) =>
      return new Promise( (resolve, reject) =>
        @base.debug __("Starting audio output")
        @_pauseUpdates = true
        
        @_device.on('loading', () =>
          
          @base.debug __("Network media player: loading")
        )
        
        @_device.on('playing', () =>
          @base.debug __("Network media player: playing")
        )
        
        @_device.on('paused', () =>
          @base.debug __("Network media player: paused")
        )
        
        @_device.on('stopped', () =>
          @base.debug __("Network media player: stopped")
          @_pauseUpdates = false
          resolve "stopped"
        )
        
        @_device.on('error', (error) =>
          @base.debug __("Network media player: error: %s", error.message)
          @_pauseUpdates = false
          @base.resetLastError()
          return @base.rejectWithErrorString( Promise.reject, error, __("Media player error during playback of: %s", url) )
        )
        
        play = @_device.play(url, 0)
        #res = env.logger.debug @
      )
      .catch( (error) =>
        @_pauseUpdates = false
        @base.resetLastError()
        @base.rejectWithErrorString Promise.reject, error
      )
      
    stopDlnaStreaming: () -> @_device.stop() if @_device? and @_presence
    
    _onDiscoveryEnd: () =>
      @_setPresence(false) if !@_detected
      @_detected = false
      
  return MediaPlayerDevice