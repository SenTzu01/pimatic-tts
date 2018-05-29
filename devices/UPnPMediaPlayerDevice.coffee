module.exports = (env) ->
  
  _ = env.require 'lodash'
  commons = require('pimatic-plugin-commons')(env)
  Promise = env.require 'bluebird'
  t = env.require('decl-api').types
  MediaPlayerDevice = require('./MediaPlayerDevice')(env)
  MediaPlayerController = require('../lib/MediaPlayerController')(env)
    
  class UPnPMediaPlayerDevice extends MediaPlayerDevice
    
    constructor: (@config, lastState, @_listener, @debug = false) ->
      @id = @config.id
      @name = @config.name
      
      @_controller = null
      #@on('xml', (xml) => @_controller = @_newController(xml, @debug) )
      
      super(lastState)
      
    destroy: -> super()
    
    playAudio: (url, outputDuration, volume = 40) =>
      return new Promise( (resolve, reject) =>
        @_disableUpdates()
        opts = {
          contentType: 'audio/mp3'
          duration: outputDuration
        }
        
        @_controller = @_newController(@_xml) if !@_controller?
        @_controller
          .once('stopped', ()     => resolve @_onStopped() )
          .once('error', (error)  => reject @_errorHandler(error) )
          .load(url, opts, (error, result) =>
            if error?
              @_debug __("error - code: %s, message: %s", error.code, error.message)
            reject error if error?
          
            @_debug result
            @_controller.play( (error, result) =>
              reject error if error?
              
              @_debug result
              @_controller.getMediaInfo( (error, result) =>
                reject error if error?
                
                @_debug result
                @_controller.getTransportInfo( (error, result) =>
                  reject error if error?
                  
                  @_debug result
                )
              )
            )
          )
      )
      .catch( (error) =>
        Promise.reject @_errorHandler(error)
      )
    
    stop: () =>
      @_controller.stop() if @_controller?
    
    _onStopped: () =>
      @_logStatus( "stopped" )
      @_enableUpdates()
      return "success"
    
    _errorHandler: (error) =>
      @base.resetLastError()
      @_logStatus( __("error - ", error.message) )
      @_enableUpdates()
      return error
    
    _getController: (xml) =>
      controller = new MediaPlayerController(xml, @debug)
        .on("loading", () => @_logStatus( "loading" ) )
        .on("playing", () => @_logStatus( "playing" ) )
        .on("paused", ()  => @_logStatus( "paused" ) )
      return controller
    
    _newController: (xml) =>
      @_controller = null
      return @_getController(xml)
      
    _logStatus: (status) => @_debug( __("Network media player: %s", status) )
    
  return UPnPMediaPlayerDevice