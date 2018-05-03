module.exports = (env) ->

  events = require('events')
  dgram = require('dgram')
  
  class SSDP extends events.EventEmitter
    _BROADCAST_ADDR: '239.255.255.250'
    _BROADCAST_PORT: 1900
    _SEND_INTERVAL: 5000
    _SSDP_HEADER: /^([^:]+):\s*(.*)$/
    
    constructor: (port) ->
      super()
      
      @_mSearch = __('M-SEARCH * HTTP/1.1\r\nHost: %s:%s\r\nMan: "ssdp:discover"\r\nST: $st\r\nMX: 3\r\n\r\n', @_BROADCAST_ADDR, @_BROADCAST_PORT)
      
      @_interval = null
      @_processed = []
      
      @_socket = dgram.createSocket('udp4')
      @_socket.on('message', @_parseResponse)
      
      @_socket.bind(port, () =>
        @_socket.addMembership(@_BROADCAST_ADDR)
      )
    
    destroy: () ->
      @_socket.close()
      @_socket = null
      return if !@_interval
      clearInterval(@_interval)
    
    search: (st) =>
      send = => @_sendDatagram(st)
      
      send()
      @_interval = setInterval( send, @_SEND_INTERVAL )
    
    onResponse: (callback) => @on('response', callback)
    
    _sendDatagram: (st) =>
      message = new Buffer( @_mSearch.replace('$st', st), 'ascii' )
      @_socket.send(message, 0, message.length, @_BROADCAST_PORT, @_BROADCAST_ADDR)
      
    _parseResponse: (message, rinfo) =>
      return if @_processed.indexOf(rinfo.address) != -1
      
      response = message.toString()
      return if @_getStatusCode(response) != 200
      
      headers = @_getHeaders(response)
      
      @_processed.push(rinfo.address)
      @emit('response', headers, rinfo)
    
    _getStatusCode: (res) =>
      lines = res.split('\r\n')
      type = lines.shift().split(' ')
      
      return parseInt(type[1], 10)
    
    _getHeaders: (res) =>
      headers = {}
      
      lines = res.split('\r\n')
      lines.map( (line) =>
        if line.length
          pairs = line.match(@_SSDP_HEADER)
          headers[pairs[1].toUpperCase()] = pairs[2] if pairs
      )
      
      return headers
    
  return SSDP