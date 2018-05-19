module.exports = (env) ->
  
  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  events = require('events')
  commons = require('pimatic-plugin-commons')(env)
  http = require('http')
  SSDP = require('./SSDP')(env)
  
  class MediaPlayerDiscovery extends events.EventEmitter
    
    _getDeviceConfig: () -> throw new Error( __("function _getDeviceConfig not implemented.") )
    
    constructor: () ->
      @base = commons.base @, @name
      @base.error __("Instance creation failed. _browseInterval and _browseDuration parameters must be passed to the constructor") if !@_browseInterval? or !@_browseDuration?
      
      @_listener = null
      
      @_timerStartBrowser = null
      @_timerStopBrowser = null
    
    destroy: () ->
      @stop()
    
    start: () =>
      @_timerStartBrowser = setTimeout(@_startBrowser, @_browseInterval)
      
    stop: () =>
      @base.debug _("Stopping SSDP discovery due to external instruction")
      clearTimeout @_timerStartBrowser if @_timerStartBrowser?
      clearTimeout @_timerStopBrowser if @_timerStopBrowser?
      @_stopBrowser()
    
    _stopBrowser: () =>
      @_listener.destroy()
      @_listener = null
      
      @base.debug __("Media player discovery stopped\n")
      @emit('discoveryStopped', true)
    
    _startBrowser: () =>
      @_debug( __("Media player discovery started") )
      
      @_listener = new SSDP(@address, @port, @_debug)
      
      @_listener.on('ssdpResponse', @_onSsdpResponse)
      @_listener.search( @_schema )
      
      @emit('discoveryStarted', true)
      
      @_timerStopBrowser = setTimeout(@_stopBrowser, @_browseDuration)
      @_timerStartBrowser = setTimeout(@_startBrowser, @_browseInterval)
      
      return
    
    _onSsdpResponse: (headers, rinfo) =>
      if headers['LOCATION'] and headers['LOCATION'].indexOf('https://') < 0
        
        @_getXml(headers.LOCATION)
        .then( (xml) =>
          config = @_getDeviceConfig(headers, xml)
          fname = @_getFriendlyName(xml)
          
          if config? and fname?
            config.id =       @_createDeviceId(fname, @_type)
            config.name =     @_createDeviceName(fname)
            config.type =     @_type
            config.address =  rinfo.address
            
            @base.debug ( __("Emitting device announcement for %s - %s", config.address, config.id) )
            
            @emit('deviceDiscovered', config)
        )
        
    _getFriendlyName: (xml) =>
      matches = xml.match(/<friendlyName>(.+?)<\/friendlyName>/)
      return matches[1] if matches?
    
    _getXml: (url) =>
      return new Promise( (resolve, reject) =>
      
        request = http.request(url)
        request.on('response', (res) =>
          body = ''
          
          res.on('data', (chunk) =>
            body += chunk
          )
          
          res.on('end', () =>
            resolve body
          )
          
          res.on('error', (error) =>
            reject error
          )
        )
        request.end()
      )
      .catch( (error) =>
        @base.resetLastError()
        @base.rejectWithErrorString( Promise.reject, error, __("There was an error obtaining the XML document") )
      )
    
    _safeString: (string, char) => return string.replace(/(^[\W]|[\W]$)/g, '').replace(/[\W]+/g, char)
    _createDeviceId: (fname, type) -> return __("%s-%s", type, @_safeString( fname, '-').toLowerCase() )
    _createDeviceName: (fname) -> return __("Media player %s", @_safeString( fname, ' ') )
    
    _debug: (msg) ->
      if typeof msg is 'object'
        util = require('util')
        msg = util.inspect( msg, {showHidden: true, depth: null } )
      env.logger.debug __("[%s] %s", @name, msg) if @debug
  
  return MediaPlayerDiscovery