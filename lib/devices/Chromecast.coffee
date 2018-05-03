module.exports = (env) ->

  Device = require('./Device')(env)
  Client = require('castv2-client').Client
  MediaReceiver = require('castv2-client').DefaultMediaReceiver

  class Chromecast extends Device

    constructor: (opts) ->
      super()
      @_client = null
      @_player = null
      @_host = opts.address
      @_name = opts.name
      @_xml = opts.xml
      @_type = opts.type
    
    destroy: () ->
      super()
      
    play: (url, timestamp, mediatype) =>
      @_client.close() if @_client?
      
      @_client = new Client()
      @_client.connect(@_host, (err) =>
        return @_onError(err) if err?
        
        @_client.launch(MediaReceiver, (err, player) =>
          return @_onError(err) if err?
          
          @_player = player
          
          opts = {
            autoplay: true,
            currentTime: timestamp
          }
          
          content = {
            contentId: url,
            contentType: mediatype
          }
          
          @_player.load(content, opts, (err) =>
            return @_onError(err) if err?
          )
        )
      )
    
    stop: () =>
      return if !@_player?
      @_player.stop( () => @_player = null )
    
    _onError: (error) -> @emit('error', error)
    
  return Chromecast