module.exports = (env) ->
  
  _ = env.require 'lodash'
  commons = require('pimatic-plugin-commons')(env)
  Promise = env.require 'bluebird'
  t = env.require('decl-api').types
  
  class DLNAPlayerDevice extends env.devices.PresenceSensor

    constructor: (@config, lastState, @_plugin) ->
      @id = @config.id
      @name = @config.name
      @debug = @config.debug || false
      @debug = true
      @base = commons.base @, ""
      
      @_detected = false
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
      @base.debug __("Network Presence: %s", presence)
      super(presence)
      
    _setDevice: (device) ->
      @base.debug __("Updating network device information for %s", @id)
      @_device = device
      @emit 'host', device.host
      @emit 'type', device.type
      @emit('device', device)
    
    getDevice: () -> Promise.resolve(@_device)
    getType: () -> Promise.resolve(@_device?.type or 'N/A')
    getHost: () -> Promise.resolve(@_device?.host or '0.0.0.0')
    
    play: (url...) -> @startDlnaStreaming(url...)
    
    stopDlnaStreaming: () -> 
      return Promise.reject __('%s is not present. Cannot stop player', @_device.name) unless @_presence
      @_device.stop()
    
    startDlnaStreaming: (url, mediatype = 'audio/mp3', timestamp) ->
      return Promise.reject __('%s is not present. Cannot play: %s', @_device.name, url) unless @_presence
      
      return new Promise((resolve, reject) =>
        @_device.play(url, timestamp, mediatype)
        @_device.onError((error) => reject error)
        resolve true
      ).catch( (error) => reject(error))
    
  return DLNAPlayerDevice