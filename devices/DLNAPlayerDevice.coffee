module.exports = (env) ->
  
  _ = env.require 'lodash'
  commons = require('pimatic-plugin-commons')(env)
  Promise = env.require 'bluebird'
  t = env.require('decl-api').types
  
  class DLNAPlayerDevice extends env.devices.PresenceSensor

    constructor: (@config, lastState, @_plugin) ->
      @id = @config.id
      @name = @config.name
      @debug = true || @config.debug || false
      @base = commons.base @, "DLNAPlayerDevice"
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
      @base.debug device
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
      @type = device.type
      @emit 'host', device.host
      @emit 'type', device.type
      @emit('device', device)
    
    getDevice: () -> Promise.resolve(@_device)
    getType: () -> Promise.resolve(@_device?.type or 'N/A')
    getHost: () -> Promise.resolve(@_device?.host or '0.0.0.0')
    
    playAudio: (url) -> 
      return new Promise( (resolve, reject) =>
        env.logger.debug __("playAudio() url: %s", url)
        env.logger.debug @_device.xml
        return Promise.reject __('%s is not present. Cannot play: %s', @_device.name, url) unless @_presence
        
        @_device.on('loading', () => @base.debug __("%s is loading url: %s", @id, url) )
        @_device.on('playing', () => @base.debug __("%s has started playback of: %s", @id, url) )
        @_device.on('stopped', () => return Promise.resolve __("Finished playback of %s on @id", url, @id) )
        @_device.play(url, 0)
        
      ).catch( (error) =>
        Promise.reject error
      )
      
    stopDlnaStreaming: () -> 
      return Promise.reject __('%s is not present. Cannot stop player', @_device.name) unless @_presence
      @_device.stop()
        
          
  return DLNAPlayerDevice