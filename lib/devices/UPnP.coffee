module.exports = (env) ->

  Device = require('./Device')(env)
  MediaPlayerController = require('../MediaPlayerController')(env)


  class UPnP extends Device
    
    constructor: (opts) ->
      super(opts)
      

    play: (url, timestamp) =>
      
      @_player.stop() if @_player?
      @_debug __("@_xml: %s", @_xml)
      @_player = new MediaPlayerController(@_xml, @debug)
      
      @_player.on("loading", () => 
        @_debug __("Media player is LOADING")
        @emit("loading")
      )
      
      @_player.on("playing", () =>
        @_debug __("Media player is PLAYING")
        @emit("playing")
      )
      
      @_player.on("paused", () =>
        @_debug __("Media player is PAUSED")
        @emit("paused")
      )
      
      @_player.on("stopped", () =>
        @_debug __("Media player is STOPPED")
        @emit("stopped")
      )
      
      opts = {
        autoplay: true,
        contentType: 'audio/mp3'
      }
      
      @_debug __("in play() method, url: %s", url)
      @_player.load(url, opts, (error) =>
        env.logger.error __("Could not play %s. Error: %s", url, error.message) if error?
        return @emit('error', error) if error?
        
        @_player.seek(timestamp)
      )
    
    stop: () => @_player.stop()
    
  return UPnP