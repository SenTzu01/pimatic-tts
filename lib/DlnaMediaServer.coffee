module.exports = (env) ->
  
  Promise = env.require 'bluebird'
  events = require('events')
  http = require('http')
  StreamServer = require('mediaserver')
  path = require('path')
  
  class DlnaMediaServer extends events.EventEmitter

    constructor: (@_opts = {port: 0} ) ->
      @_httpServer = null
      @_running = false
      
      @_virtualDirRoot = '/'
      @_virtualDirMedia = path.join(@_virtualDirRoot, 'media')
      
      @_virtualResource = null
      @_physicalResource = null
      
    create: (resource) =>
      return new Promise( (resolve, reject) =>
        @_physicalResource = resource
        @_virtualResource = path.join( @_virtualDirMedia, path.basename(resource) )
        
        @_httpServer = http.createServer() if !@_httpServer?
        @_httpServer.on('request', @_requestListener)
      
        @_httpServer.on('error', (error) =>
          reject error
        )
        @_httpServer.on('clientError', (error = new Error("Undefined media player error")) =>
          @emit('clientError', error)
        )
        @_httpServer.on('connection', () =>
          env.logger.debug __("Mediaserver server established a TCP socket connection")
          @emit('serverConnected')
        )
        @_httpServer.on('connect', (request, socket, head) =>
          env.logger.debug __("client: %s connected", socket.remoteAddress)
        )
        @_httpServer.on('close', () =>
          env.logger.debug __("Server connection closed" )
          @emit('serverClose')
        )
      
        @_httpServer.listen(@_opts.port, @_opts.address, () =>
          env.logger.debug __("Mediaserver started on: ip: %s, port: %s", @_httpServer.address().address, @_httpServer.address().port)
          env.logger.debug __("Mediaserver is serving media resource: %s", @_virtualResource)
        
          @_running = true
          resolve __("http://%s:%s%s", @_httpServer.address().address, @_httpServer.address().port, @_virtualResource)
        )
        
      )
    
    _requestListener: (request, response) =>
      
      if request?
        env.logger.debug __("New request from %s: method: %s, URL: %s", request.socket.remoteAddress, request.method, request.url)
        
        response.on('close', () =>
          @emit('responseClose', new Error("Server prematurely closed the connection") ) 
        )
        response.on('finish', () => 
          env.logger.debug __("Server responded to request")
          @emit('responseComplete', response) 
        )
        request.on('aborted', () =>
          @emit('requestAborted', new Error("Client prematurely aborted the request") ) 
        )
        request.on('close', () => 
          env.logger.debug __("Client closed connection") 
          @emit('requestComplete', request.url)
        )
      
        if !@_validRequest(request)
          @_httpResponse404(response)
          env.logger.debug __("resource not found: %s", request.url)
          return
        
      env.logger.debug "piping request to media streamer"
      StreamServer.pipe(request, response, @_physicalResource)
    
    _validRequest: (request) ->
      return @_virtualResource is request?.url
    
    _httpResponse404: (response) =>
      response.writeHead(404)
      response.end()
      
      @emit('requestInvalid', request)
      
    halt: () =>
      return new Promise ( (resolve, reject) =>
        if @_running
          @_httpServer.close( (error) =>
            if error?
              env.logger.error __("Error halting Mediaserver: %s", error.message)
              env.logger.debug error.stack
          )
        @_running = false
        msg = __("Mediaserver halted")
        env.logger.debug msg
        resolve msg
      )
    
    stop: () ->
      @halt()
      .catch( (error) =>
        env.logger.error __("Error shutting down Mediaserver: %s", error.message)
        env.logger.debug error.stack
      )
      .finally( () =>
        @_httpServer = null
        
        msg = __("Mediaserver shut down")
        env.logger.debug msg
        return Promise.resolve msg
      )
    
    destroy: () ->
      @_stop()
      
  return DlnaMediaServer