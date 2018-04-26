module.exports = (env) ->
  
  _ = env.require 'lodash'
  commons = require('pimatic-plugin-commons')(env)
  Promise = env.require 'bluebird'
  t = env.require('decl-api').types
  util = require('util')
  
  class DLNAPlayerDevice extends env.devices.PresenceSensor

    constructor: (@config, lastState, @_plugin) ->
      @id = @config.id
      @name = @config.name
      @debug = true || @config.debug || false
      @base = commons.base @, "DLNAPlayerDevice"
      @_detected = false
      @_pauseUpdates = false
      @_device = lastState?.device?.value or null
      
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
      
      @_plugin.on('dlnaDeviceDiscovered', @updateDevice)
      
      onDiscoveryEnd = () =>
        @_setPresence(false) if !@_detected
        @_detected = false
      @_plugin.on('dlnaDiscoveryEnd', onDiscoveryEnd)
      
      super()

    destroy: ->
      @_plugin.removeListener('dlnaDiscoveryEnd', onDiscoveryEnd)
      @_plugin.removeListener('dlnaDeviceDiscovered', @updateDevice)
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
      @base.debug __("Updating network device information for %s", @id)
      @_device = device unless @_pauseUpdates
      @type = device.type
      @emit 'host', device.host
      
      @emit 'type', device.type
      @emit('device', device)
    
    getDevice: () -> Promise.resolve(@_device)
    getType: () -> Promise.resolve(@_device?.type or 'N/A')
    getHost: () -> Promise.resolve(@_device?.host or '0.0.0.0')
      
    _onPlayerEvent: (event, data) => 
      @base.debug __("%s Network media player: %s", @id, event)
      @emit(event, data)
      
    playAudio: (url) -> 
      return new Promise( (resolve, reject) =>
        env.logger.debug __("Starting audio output via: %s", @id)
        
        @_pauseUpdates = true
        @_device.once('loading', (data) => @_onPlayerEvent('loading', data) )
        @_device.once('playing', (data) => @_onPlayerEvent('started', data) )
        @_device.once('paused', (data) => @_onPlayerEvent('paused', data) )
        
        @_device.once('error', (error) => 
          @_onPlayerEvent('error', error)
          reject error
        )
        
        @_device.once('stopped', (data) =>
          @_onPlayerEvent('stopped', data)
          @_pauseUpdates = false
          resolve true
        )
        
        play = @_device.play(url, 0)
        env.logger.debug @_device
        
      ).catch( (error) =>
        reject error
      )
      
    stopDlnaStreaming: () -> 
      return Promise.reject __('%s is not present. Cannot stop player', @_device.name) unless @_presence
      @_device.stop()
        
          
  return DLNAPlayerDevice