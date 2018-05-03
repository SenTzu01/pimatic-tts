module.exports = (env) ->

  Device = require('./Device')(env)
  MediaPlayerController = require('../MediaPlayerController')(env)


  class UPnP extends Device
    _FORWARDED_EVENTS: [
      'loading',
      'playing',
      'paused',
      'stopped'
    ]
    
    constructor: (opts) ->
      super()
      @_host = opts.address
      @_name = opts.name
      @_xml = opts.xml
      @_type = opts.type
      @_player = null

    play: (url, timestamp) =>
      opts = {
        autoplay: true
      }
      
      @_player.stop() if @_player?
      @_player = new MediaPlayerController(@_xml)
      
      @_FORWARDED_EVENTS.map( (event) => @_player.on( event, () => @emit(event) ) )
      
      @_player.load(url, opts, (error) =>
        return @emit('error', error) if error?
        
        @_player.seek(timestamp)
      )
    
    stop: () =>
      return if !@_player?
      @_player.stop( () => @_player = null )
    
  return UPnP