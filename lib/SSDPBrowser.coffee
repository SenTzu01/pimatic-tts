module.exports = (env) ->

  events = require('events')
  http = require('http')
  
  SSDP = require('./SSDP')(env)
  Chromecast = require('./devices/Chromecast')(env)
  UPnP = require('./devices/UPnP')(env)

  class SSDPBrowser extends events.EventEmitter

    constructor: (@port, @debug = false) ->
      
      @_devices = []
      @_listeners = []
      
      @on('deviceFound', (device) =>
        @_debug __("New device discovered")
      )
      
    destroy: () ->
      @stop()
    
    stop: () ->
      @_listeners.map( (listener) -> listener.destroy() )
      @_listeners = []
      
    start: () ->
      @_searchChromecast()
      @_searchUPnP()
    
    getList: () -> return @_devices
    
    _searchChromecast: () =>
      ST = 'urn:dial-multiscreen-org:service:dial:1'
      
      @on('googleDevice', (headers, rinfo, xml) =>
        type = 'chromecast'
        name = @_getFriendlyName(xml)
        return if !name?
        
        device = new Chromecast({
          id: @_createDeviceId(type, name)
          name: __("Chromecast client %s", @_safeString(name) )
          address: rinfo.address,
          xml: xml,
          type: type
          debug: @debug
        })
        @_devices.push(device)
        @emit('deviceFound', device)
      )
      
      @_createListener(ST)
    
    _searchUPnP: () =>
      ST = 'urn:schemas-upnp-org:device:MediaRenderer:1'
      
      @on('genericDevice', (headers, rinfo, xml) =>
        return if headers.ST != ST
        type = 'generic'
        name = @_getFriendlyName(xml)
        return if !name?
        
        device = new UPnP({
          id: @_createDeviceId(type, name)
          name: __("Media player %s", @_safeString(name, ' ') )
          address: rinfo.address,
          xml: headers['LOCATION'],
          type: type
          debug: @debug
        })
        @_debug __("Media player object created: %s", device.id)
        @_devices.push device
        @emit('deviceFound', device)
      )
      
      @_createListener(ST)
    
    _createListener: (schema) ->
      listener = new SSDP(@port, @debug)
      listener.on('ssdpResponse', (headers, rinfo) =>
        env.logger.debug headers
        if headers['LOCATION'] and headers['LOCATION'].indexOf('https://') < 0
          @_getXML(headers['LOCATION'], (xml) =>
            env.logger.debug xml
            vendor = 'generic'
            vendor = 'google' if xml.search('<manufacturer>Google Inc.</manufacturer>') > -1
            @emit( __("%sDevice", vendor), headers, rinfo, xml)
          )
      )
      listener.search(schema)
      @_listeners.push(listener)
    
    _getXML: (address, callback) =>
      http.get(address, (res) =>
        body = ''
        
        res.on('data', (chunk) => body += chunk )
        res.on('end', () => callback(body) )
      )
    
    _getFriendlyName: (xml) =>
      matches = xml.match(/<friendlyName>(.+?)<\/friendlyName>/)
      return if !matches?
      
      return matches[1]
    
    _safeString: (string, char) => return string.replace(/(^[\W]|[\W]$)/g, '').replace(/[\W]+/g, char)
    _createDeviceId: (type, name) => return __("%s-%s", type, @_safeString(name, '-').toLowerCase() )
    _debug: (msg) -> env.logger.debug __("[SSDPBrowser] %s", msg) if @debug
    
  return SSDPBrowser