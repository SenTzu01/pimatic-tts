module.exports = (env) ->
  
  Promise = env.require 'bluebird'
  events = require('events')
  http = require('http')
  StreamServer = require('mediaserver')
  path = require('path')
  
  ###
  #
  # Usage:
  #
  # mediaServer = new DlnaMediaServer()
  #
  # mediaServer.on('ready', (url) =>
  #   #Do your magic here, e.g. tell a DLNA device to start playing the url
  # )
  #
  # mediaServer.on('responseFinish', () =>
  #   # Do what needs to be done after serving the resource is completed
  # )
  #
  # # Setup error event handlers
  #
  # onError = (error) =>
  #   error ?= "Undefined error"
  #   throw new error if error?
  #   mediaServer.stop()
  # mediaServer.on('responseClose', onError)
  # mediaServer.on('clientError', onError)
  #
  # resource = '/path/to/resource.mp3'
  # opts = { port: 8080} #(optional, else the listen port will be dynamically allocated)
  # mediaServer.create(opts)
  # mediaServer.start(resource)
  # 
  #
  #
  ###
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
        
        @_httpServer = http.createServer()
        
        @_httpServer.on('request', @_requestListener)
        
        @_httpServer.on('error', (error) => return Promise.reject error )
        @_httpServer.on('clientError', (error = "undefined") => @emit('clientError', new Error(error) ) )
        
        
        @_httpServer.on('connection', () =>
          env.logger.debug __("Mediaserver server established a TCP socket connection")
          @emit('serverConnected')
        
        )
        
        @_httpServer.on('connect', (request, socket, head) => env.logger.debug __("client: %s connected", socket.remoteAddress) )
        
        @_httpServer.on('close', () =>
          env.logger.debug __("Server connection closed" )
          @emit('serverClose')
        
        )
        
        @_httpServer.listen(@_opts.port, @_opts.address, () =>
          env.logger.debug __("Mediaserver started: ip: %s, port: %s", @_httpServer.address().address, @_httpServer.address().port)
          @_running = true
          
          resolve __("http://%s:%s%s", @_httpServer.address().address, @_httpServer.address().port, @_virtualResource)
        
        )
      ).catch( (error) => 
        Promise.reject error
      )
    
    _requestListener: (request, response) =>
      env.logger.debug "in _requestHandler()"
      #request.on('aborted', () => @emit('requestAborted', new Error("Client prematurely aborted the request") ) )
      #response.on('close', () => @emit('responseClose', new Error("Server prematurely closed the connection") ) )
      #request.on('close', () => 
      #  env.logger.debug __("Client closed connection") 
      #  @emit('requestComplete', request.url)
      #)
      
      #response.on('finish', () => 
      #  env.logger.debug __("Server responded to request")
      #@emit('responseComplete', response) )

      env.logger.debug __("_requestListener, request:")
      env.logger.debug request
      
      if @_virtualResource != request?.url
        body = http.STATUS_CODES[404]
        response.writeHead(404, body, {
          'Content-Length': Buffer.byteLength(body)
          'Content-Type': 'text/plain'
        })
        response.end()
        
        env.logger.debug __("resource not found: %s", request.url)
        @emit('requestInvalid', request)
        #response.write("Target Not Found!" )
        #response.end()
        return
        
      env.logger.debug "piping request to StreamServer"
      StreamServer.pipe(request, response, @_physicalResource)
        
    pause: () =>
      @_httpServer.close() if @_running
      
      @_httpServer = null
      @_running = false
    
    stop: () ->
      @_httpServer.pause() if @_running
      @_httpServer = null
    
    destroy: () ->
      @_stop()
      
  return DlnaMediaServer