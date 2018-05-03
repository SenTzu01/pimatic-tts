module.exports = (env) ->

  events = require('events')
  http = require('http')
  
  SSDP = require('./SSDP')(env)
  Chromecast = require('./devices/Chromecast')(env)
  UPnP = require('./devices/UPnP')(env)

  class SSDPBrowser extends events.EventEmitter

    constructor: (@debug = false) ->
      
      @_devices = []
      
      @_chromecastSSDP = new SSDP()
      @_upnpSSDP = new SSDP()
      
      @_chromecastSSDP.on('ssdpResponse', @_onSSDPResonse)
      @_upnpSSDP.on('ssdpResponse', @_onSSDPResonse)
      
      @on('deviceFound', (device) =>
        return unless @debug
        env.logger.debug __("SSDPBrowser: New device discovered")
        env.logger.debug devices
      )
      
    destroy: () -> 
      @_chromecastSSDP.destroy()
      @_upnpSSDP.destroy()
    
    stop: () ->
      @_chromecastSSDP.destroy()
      @_upnpSSDP.destroy()
    
    start: () ->
      @_searchChromecast()
      @_searchUPnP()
    
    getList: () -> return @_devices
    
    _searchChromecast: () =>
      @on('googleDevice', (headers, rinfo, xml) =>
        type = 'chromecast'
        name = @_getFriendlyName(xml)
        return if !name?
        
        device = new Chromecast({
          id: @_createDeviceId(type, name)
          name: __("Chromecast %s", @_safeString(name) )
          address: rinfo.address,
          xml: xml,
          type: type
        })
        
        @_devices.push(device)
        @emit('deviceFound', device)
      )
      @_chromecastSSDP.search('urn:dial-multiscreen-org:service:dial:1')
    
    _searchUPnP: () =>
      @on('genericDevice', (headers, rinfo, xml) =>
        type = 'upnp'
        name = @_getFriendlyName(xml)
        return if !name?
        
        device = new UPnP({
          id: @_createDeviceId(type, name)
          name: __("Media player %s", @_safeString(name, ' ') )
          address: rinfo.address,
          xml: headers['LOCATION'],
          type: type
        })
        
        @_devices.push device
        @emit('deviceFound', device)
      )
      @_upnpSSDP.search('urn:schemas-upnp-org:device:MediaRenderer:1')
    
    _onSSDPResonse: (headers, rinfo) =>
      return if !headers['LOCATION'] or headers['LOCATION'].indexOf('https://') != -1
      
      @_getXML(headers['LOCATION'], (xml) =>
        vendor = 'generic'
        vendor = 'google' if xml.search('<manufacturer>Google Inc.</manufacturer>') != -1
        @emit( __("%sDevice", vendor), headers, rinfo, xml)
      )
    
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
    
  return SSDPBrowser