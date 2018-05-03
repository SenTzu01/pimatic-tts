module.exports = (env) ->

  events = require('events')
  http = require('http')
  
  SSDP = require('./SSDP')(env)
  Chromecast = require('./devices/Chromecast')(env)
  UPnP = require('./devices/UPnP')(env)

  class SSDPBrowser extends events.EventEmitter

    constructor: () ->
      super()
      
      @_chromecastSSDP = new SSDP(3333)
      @_upnpSSDP = new SSDP(3334)
      @_devices = []
    
    _searchChromecast: () =>
      
      @_search(@_chromecastSSDP, (headers, rinfo, xml) =>
        return if xml.search('<manufacturer>Google Inc.</manufacturer>') is -1
        
        name = @_getFriendlyName(xml)
        return if !name?
        
        device = new Chromecast({
          name: name,
          address: rinfo.address,
          xml: xml,
          type: 'chc'
        })
        
        @_devices.push(device)
        @emit('deviceOn', device)
      )
      @_chromecastSSDP.search('urn:dial-multiscreen-org:service:dial:1')
    
    _searchUPnP: () =>
    
      @_search(@_upnpSSDP, (headers, rinfo, xml) =>
        name = @_getFriendlyName(xml)
        return if !name?
        
        device = new UPnP({
          name: name,
          address: rinfo.address,
          xml: headers['LOCATION'],
          type: 'upnp'
        })
        
        @_devices.push device
        @emit('deviceOn', device)
      )
      
      @_upnpSSDP.search('urn:schemas-upnp-org:device:MediaRenderer:1')
    
    _search: (ssdp, callback) =>
      ssdp.onResponse( (headers, rinfo) =>
        return if !headers['LOCATION'] or headers['LOCATION'].indexOf('https://') != -1
        
        @_getXML(headers['LOCATION'], (xml) =>
          callback(headers, rinfo, xml)
        )
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
  
    start: () ->
      @_searchChromecast()
      @_searchUPnP()
      
    destroy: () ->
      @_chromecastSSDP.destroy()
      @_upnpSSDP.destroy()
    
    onDevice: (callback) => @on('deviceOn', (device) =>
      callback(device)
    )

    getList: () -> return @_devices

  return SSDPBrowser