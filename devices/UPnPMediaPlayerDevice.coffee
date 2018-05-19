module.exports = (env) ->
  
  _ = env.require 'lodash'
  commons = require('pimatic-plugin-commons')(env)
  Promise = env.require 'bluebird'
  t = env.require('decl-api').types
  MediaPlayerDevice = require('./MediaPlayerDevice')(env)
  MediaPlayerController = require('../lib/MediaPlayerController')(env)
    
  class UPnPMediaPlayerDevice extends MediaPlayerDevice
    
    constructor: (@config, lastState, @_listener, @debug = false) ->
      @base = commons.base @, "UPnPMediaPlayerDevice"
      @id = @config.id
      @name = @config.name
      
      @_controller = null
      
      super(lastState)
      
    destroy: -> super()
    
    playAudio: (url, timestamp = 0) =>
      return new Promise( (resolve, reject) =>
        @_pauseUpdates = true
        
        opts = {
          autoplay: true,
          contentType: 'audio/mp3'
        }
        
        controller = @_getController()
        controller.on('stopped', () =>    return @_onStopped() )
        controller.on('error', (error) => return @_onError(error) )
          
        controller.load(url, opts, (error) =>
          return @_onError(error) if error?
          
          controller.seek(timestamp)
        )
      )
      .catch( (error) =>
        @_pauseUpdates = false
        @base.resetLastError()
        @base.rejectWithErrorString Promise.reject, error
      )
    
    stop: () =>
      @_controller.stop() if @_controller?
      @_controller = null
    
    _getController: () =>
      
      @_controller = new MediaPlayerController(@_xml, @debug)
        .on("loading", () => 
          @base.debug __("Network media player: loading")
        )
      
        .on("playing", () =>
          @base.debug __("Network media player: playing")
        )
        
        .on("paused", () =>
          @base.debug __("Network media player: paused")
        )
      return @_controller
    
    _onError: (error) =>
      @base.debug __("Network media player: error: %s", error.message)
      
      @stop()
      @_pauseUpdates = false
      @base.resetLastError()
      @emit('error', err)
      
      return @base.rejectWithErrorString( Promise.reject, error, __("Media player error during playback") )
    
    _onStopped: () =>
      @base.debug __("Network media player: stopped")
      
      @_pauseUpdates = false
      @emit('stopped')
      
      return Promise.resolve true
    
  return UPnPMediaPlayerDevice