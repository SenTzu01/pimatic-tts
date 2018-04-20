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
      @base = commons.base @, "#{@id}"
      
      @_updated = false
      @_dlnaDevice = null
      
      @addAction('streamResource', {
        description: "Stream a resource to the DLNA device"
        params:
          url:
            type: t.string})
      
      @addAction('updatePlayer', {
        description: "Update DLNA network presence"
        params:
          player:
            type: t.object})
      
      @addAction('play', {
        description: "Start playback on the DLNA Device"})
      
      @addAction('pause', {
        description: "Pauses playback on the DLNA Device"})
      
      @addAction('stop', {
        description: "Stop playback on the DLNA Device"})
      
      onDeviceDiscovered = (config) =>
        return unless config.id is @id
        @updateDevice(true, config)
        return @_updated = true
      @_plugin.on('dlnaDeviceDiscovered', onDeviceDiscovered)
      
      disableDevice = () =>
        if !@_updated
          @updateDevice(false)
        @_updated = false
        return !@updated
      @_plugin.on('dlnaDiscoveryEnd', disableDevice)
      
      super()

    destroy: ->
      @_plugin.removeListener('dlnaDiscoveryEnd', disableDevice)
      @_plugin.removeListener('dlnaDeviceDiscovered', onDeviceDiscovered)
      super()
      
    updateDevice: (state, config) ->
      @_setConfig(config) if state
      return @_setState(state)
    
    _setState: (state) ->
      @base.debug __("Setting DLNA device %s presence to: %s", @id, state)
      @_setPresence(state)
      
    _setConfig: (config) -> 
      @base.debug __("Updating DLNA device information for %s", @id)
      @_dlnaDevice = config
    
    streamResource: (url, timestamp) ->
      return Promise.reject __('%s is not present. Cannot play: %s', @_dlnaDevice.name, url) unless @_presence
      player = @_dlnaDevice
      
      return new Promise((resolve, reject) =>
        player.play(url, timestamp)
        player.onError((error) => reject error)
        resolve true
      ).catch( (error) => reject(error))

    _executeOnPlayer: (cb) ->
      if !@_presence or @_dlnaDevice is null
        return Promise.reject(@_dlnaDevice.name + ' is not present.')
      player = @_dlnaDevice
      return new Promise((resolve, reject) =>
        try
          cb(player, => resolve("DONE"))
        catch e
          reject(e)
      )

    stop: -> @_executeOnPlayer( (player, cb) => player.stop(cb) )
    play: -> @_executeOnPlayer( (player, cb) => player.resume(cb) )
    pause: -> @_executeOnPlayer( (player, cb) => player.pause(cb) )
  
  return DLNAPlayerDevice