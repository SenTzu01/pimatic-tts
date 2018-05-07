module.exports = (env) ->

  Device = require('./Device')(env)
  MediaPlayerController = require('../MediaPlayerController')(env)


  class UPnP extends Device
    
    constructor: (opts) ->
      super(opts)
      
      @_player = new MediaPlayerController(@_xml, @debug)

    play: (url, timestamp) =>
      
      @_player.stop() if @_player?
      
      @_player.on("loading", () => 
        @emit("loading")
      )
      
      @_player.on("playing", () =>
        @emit("playing")
      )
      
      @_player.on("paused", () =>
        @emit("paused")
      )
      
      @_player.on("stopped", () =>
        @emit("stopped")
      )
      
      opts = {
        autoplay: true,
        contentType: 'audio/mp3'
      }
      
      @_player.load(url, opts, (error) =>
        env.logger.error __("Could not play %s. Error: %s", url, error.message) if error?
        return @emit('error', error) if error?
        
        @_player.seek(timestamp)
      )
    
    stop: () => @_player.stop()
    
  return UPnP