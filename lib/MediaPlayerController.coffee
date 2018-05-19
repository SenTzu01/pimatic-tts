module.exports = (env) ->

  DeviceClient = require('upnp-device-client')
  et = require('elementtree')
  util = require('util')
  
  # The MediaPlayerController Object exposes methods to remotely control a Media player
  # It also emits events on Media player status changes
  
  class MediaPlayerController extends DeviceClient
    _MEDIA_EVENTS: [
      'status',
      'loading',
      'playing',
      'paused',
      'stopped',
      'speedChanged'
    ]
    
    _TRANSPORT_STATES: {
      TRANSITIONING: 'loading'
      PLAYING: 'playing'
      PAUSED_PLAYBACK: 'paused'
      STOPPED: 'stopped'
    }
    
    constructor: (url, @debug = false) ->
      super(url, env, @debug)
      
      @_refs = 0
      @_receivedState = null
      @_instanceId = 0
      
      @on('newListener', (eventName, listener) =>
        return if @_MEDIA_EVENTS.indexOf(eventName) is -1
      
        if @_refs is 0
          @_receivedState = false
          @subscribe('AVTransport', @_onstatus)
        @_refs++
      )
    
      @on('removeListener', (eventName,listener) =>
        return if @_MEDIA_EVENTS.indexOf(eventName) is -1
        
        @_refs--
        @unsubscribe('AVTransport', @_onstatus) if @_refs is 0
      )
    
    destroy: () ->
      super()
    
    getSupportedProtocols: (callback) =>
      @callAction('ConnectionManager', 'GetProtocolInfo', {}, (err, result) =>
        return callback(err) if err?
        
        # Here we leave off the `Source` field as we're hopefuly dealing with a Sink-only device.
        lines = result.Sink.split(',')
        
        protocols = lines.map( (line) =>
          
          tmp = line.split(':')
          return {
            protocol: tmp[0],
            network: tmp[1],
            contentFormat: tmp[2],
            additionalInfo: tmp[3]
          }
        )
        callback(null, protocols)
      )
    
    getPosition: (callback) =>
      @callAction('AVTransport', 'GetPositionInfo', { InstanceID: @_instanceId }, (err, result) =>
        return callback(err) if err?
        
        str = if result.AbsTime != 'NOT_IMPLEMENTED' then result.AbsTime else result.RelTime
        callback( null, @_parseTime(str) )
      )
    
    getDuration: (callback) =>
      @callAction('AVTransport', 'GetMediaInfo', { InstanceID: @_instanceId }, (err, result) =>
        return callback(err) if err?
        
        callback( null, @_parseTime(result.MediaDuration) )
      )
    
    load: (url, options, callback) =>
      if typeof options is 'function'
        callback = options
        options = {}
      
      contentType = options.contentType ? 'video/mpeg'
      protocolInfo = __( "http-get:*:%s:*", contentType )
      
      metadata = options.metadata ? {}
      metadata.url = url
      metadata.protocolInfo = protocolInfo
      
      params = {
        RemoteProtocolInfo: protocolInfo,
        PeerConnectionManager: null,
        PeerConnectionID: -1,
        Direction: 'Input'
      }
      
      @callAction('ConnectionManager', 'PrepareForConnection', params, (err, result) =>
        return callback(err) if err? and err.code != 'ENOACTION'
        #console.log result
        #@_debug(result)
        
        # If PrepareForConnection is not implemented, we keep the default (0) InstanceID
        @_instanceId = result.AVTransportID if result?.AVTransportID?
        
        params = {
          InstanceID: @_instanceId,
          CurrentURI: url,
          CurrentURIMetaData: @_buildMetadata(metadata)
        }
        
        @callAction('AVTransport', 'SetAVTransportURI', params, (err) =>
          return callback(err) if err?
          
          if options.autoplay
            @play(callback)
            return
          
          callback()
        )
      )
      
    play: (callback) =>
      params = {
        InstanceID: @_instanceId,
        Speed: 1
      }
      
      @callAction( 'AVTransport', 'Play', params, callback ? @_noOp )
    
    pause: (callback) =>
      params = {
        InstanceID: @_instanceId
      }
      @callAction( 'AVTransport', 'Pause', params, callback ? @_noOp )
    
    stop: (callback) =>
      params = {
        InstanceID: @_instanceId
      }
      
      @callAction( 'AVTransport', 'Stop', params, callback ? @_noOp )
    
    seek: (seconds, callback) =>
      params = {
        InstanceID: @_instanceId,
        Unit: 'REL_TIME',
        Target: @_formatTime(seconds)
      }
      
      @callAction( 'AVTransport', 'Seek', params, callback ? @_noOp )
    
    getVolume: (callback) =>
      params = {
        InstanceID: @_instanceId,
        Channel: 'Master'
      }
      
      @callAction('RenderingControl', 'GetVolume', params, (err, results) =>
        return callback(err) if err?
        
        callback( null, parseInt(result.CurrentVolume) )
      )
    
    setVolume: (volume, callback) =>
      params = {
        InstanceID: @_instanceId,
        Channel: 'Master',
        DesiredVolume: volume
      }
      
      @callAction( 'RenderingControl', 'SetVolume', params, callback ? @_noOp )
    
    _onstatus: (e) =>
      @emit('status', e)
      
      @_debug __("Status received: %s", util.inspect(e, {showHidden: true, depth: null }))
      
      if !@_receivedState
        # Ignore first state (Full state)
        @_receivedState = true
        return
      
      if e.hasOwnProperty('TransportState')
        @_debug( __("Emitting event: %s", @_TRANSPORT_STATES[e.TransportState]) )
        @emit( @_TRANSPORT_STATES[e.TransportState] )
      @emit( 'speedChanged', Number(e.TransportPlaySpeed) ) if e.hasOwnProperty('TransportPlaySpeed')
    
    _formatTime: (seconds) ->
      h = Math.floor((seconds - (h * 0)     - (m * 0 )) / 3600)
      m = Math.floor((seconds - (h * 3600)  - (m * 0 )) / 60)
      s =            (seconds - (h * 3600)  - (m * 60))
      
      pad = (v) -> return if v < 10 then '0' + v else v
      return [pad(h), pad(m), pad(s)].join(':')
    
    _parseTime: (time) ->
      parts = time.split(':').map(Number)
      return parts[0] * 3600 + parts[1] * 60 + parts[2]
    
    _buildMetadata: (metadata) =>
      didl = et.Element('DIDL-Lite')
      didl.set('xmlns', 'urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/')
      didl.set('xmlns:dc', 'http://purl.org/dc/elements/1.1/')
      didl.set('xmlns:upnp', 'urn:schemas-upnp-org:metadata-1-0/upnp/')
      didl.set('xmlns:sec', 'http://www.sec.co.kr/')
      
      item = et.SubElement(didl, 'item')
      item.set('id', 0)
      item.set('parentID', -1)
      item.set('restricted', false)
      
      if metadata?
        OBJECT_CLASSES = {
          'audio': 'object.item.audioItem.musicTrack',
          'video': 'object.item.videoItem.movie',
          'image': 'object.item.imageItem.photo'
        }
        
        if metadata.type?
          klass = et.SubElement(item, 'upnp:class')
          klass.text = OBJECT_CLASSES[metadata.type]
        
        if metadata.title?
          title = et.SubElement(item, 'dc:title')
          title.text = metadata.title
        
        if metadata.creator?
          creator = et.SubElement(item, 'dc:creator')
          creator.text = metadata.creator
        
        if metadata.url? and metadata.protocolInfo?
          res = et.SubElement(item, 'res')
          res.set('protocolInfo', metadata.protocolInfo)
          res.text = metadata.url
        
        if metadata.subtitlesUrl?
          captionInfo = et.SubElement(item, 'sec:CaptionInfo')
          captionInfo.set('sec:type', 'srt')
          captionInfo.text = metadata.subtitlesUrl
          
          captionInfoEx = et.SubElement(item, 'sec:CaptionInfoEx')
          captionInfoEx.set('sec:type', 'srt')
          captionInfoEx.text = metadata.subtitlesUrl
          
          # Create a second `res` for the subtitles
          res = et.SubElement(item, 'res')
          res.set('protocolInfo', 'http-get:*:text/srt:*')
          res.text = metadata.subtitlesUrl
          
        doc = new et.ElementTree(didl)
        
        xml_opts = { xml_declaration: false }
        xml = doc.write(xml_opts)
        
        return xml
    
    _noOp: () -> return undefined
    
    _debug: (msg) =>
      if typeof msg is 'object'
        msg = util.inspect( msg, {showHidden: true, depth: null } )
      env.logger.debug __("[MediaPlayerController] %s", msg) if @debug
    
  return MediaPlayerController
