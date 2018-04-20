module.exports = (env) ->
  
  _ = env.require 'lodash'
  commons = require('pimatic-plugin-commons')(env)
  Promise = env.require 'bluebird'
  t = env.require('decl-api').types
  
  class DLNAPlayerDevice extends env.devices.PresenceSensor

    constructor: (@config, lastState, @_plugin) ->
      @id = @config.id
      @name = @config.name
      
      @base = commons.base @, "#{@id}"
      @debug = true
      
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
      
      @_plugin.on('dlnaDeviceDiscovered', @_onDeviceDiscovered)
      @_plugin.on('dlnaDiscoveryEnd', @_disableDevice)
      
      super()

    destroy: ->
      @_plugin.removeListener('dlnaDiscoveryEnd', @_disableDevice)
      @_plugin.removeListener('dlnaDeviceDiscovered', @_onDeviceDiscovered)
      super()
    
    _onDeviceDiscovered: (config) =>
      @base.debug "dlnaDeviceDiscovered event received"
      return unless config.id is @id
      @updateDevice(true, config)
      return @_updated = true
      
    _disableDevice: (list) =>
      @base.debug "dlnaDiscoveryEnd event received"
      @updateDevice(false) if !@_updated
      @_updated = false
      return !@updated
       
    updateDevice: (state, config) ->
      @_setConfig(config) if state
      return @_setState(state)
    
    _setState: (state) ->
      @base.debug __("Setting DLNA device presence to: %s", state)
      @_setPresence(state)
      
    _setConfig: (config) -> 
      @base.debug "Updating DLNA device information"
      @_dlnaDevice = config
    
    streamResource: (url, mediaType) ->
      return Promise.reject __('%s is not present. Cannot play: %s', @_player.name, url) unless @_presence
      player = @_player
      
      return new Promise((resolve, reject) =>
        player.stop( () =>
          
          player.play(url,  {type: mediaType}, () => 
            resolve("DONE") 
          )
        
        )
      ).catch( (error) => reject(error))

    _executeOnPlayer: (cb) ->
      if !@_presence or @_player is null
        return Promise.reject(@name + ' is not present.')
      player = @_player
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