module.exports = (env) ->

  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  t = env.require('decl-api').types
  commons = require('pimatic-plugin-commons')(env)
  fs = require('fs')
  Crypto = require('crypto')
  Volume = require('pcm-volume')
  Speaker = require('speaker')
  MediaServer = require('../lib/MediaServer')(env)
  path = require('path')
  mp3Duration = require('mp3-duration')
  
  
  class TTSDevice extends env.devices.Device
    _FILE_PREFIX: '/pimatic-tts_'
    
    attributes:
      language:
        description: "Voice synthesis language"
        type: t.string
        acronym: 'Language:'
        discrete: true
      volume:
        description: "Voice volume"
        type: t.number
        acronym: 'Volume:'
        discrete: true
      repeat:
        description: "Repeats of same message"
        type: t.number
        acronym: 'Repeat:'
        discrete: true
      interval:
        description: "Time between two repeats"
        type: t.number
        acronym: 'Interval:'
        discrete: true
    
    actions:
      getLanguageDefault:
        description: "Returns the Voice synthesis language"
        returns:
          language:
            type: t.string
      getVolumeDefault:
        description: "Returns the gain volume applied on the audio output stream"
        returns:
          volume:
            type: t.number
      getRepeatDefault:
        description: "Returns the number of times the same message is repeated"
        returns:
          repeat:
            type: t.number
      getIntervalDefault:
        description: "Returns the amount of time between two repeats"
        returns:
          interval:
            type: t.number
      textToSpeech:
        description: "Converts Text-to-Speech and outputs Audio"
        params:
          text:
            type: t.object
      
    generateResource: ()  -> @_errMethodNotImplemented('generateResource')
    getAudioFormat: ()    -> @_errMethodNotImplemented('getAudioFormat')
    _setup: ()            -> @_errMethodNotImplemented('_setup')
    
    constructor: () ->
      @base = commons.base @, @config.class
      @debug = @pluginConfig.debug ? @config.debug ? false
      
      @_mediaServer         = null
      @_mediaServerAddress  = @pluginConfig.address
      
      @_setup()
      super()
    
    getInterval: -> Promise.resolve @config.interval
    getVolume: -> Promise.resolve @config.volume
    getRepeat: -> Promise.resolve @config.repeat
    getLanguage: -> Promise.resolve @config.language
    
    getCacheDir: -> @config.tmpDir
    isCacheEnabled: -> @config.enableCache
    getSessionVolume: -> @_conversionSettings?.speech?.volume?.parsed ? @config.volume
    getSessionRepeat: -> @_conversionSettings?.speech?.repeat?.number?.parsed ? @config.repeat
    getSessionInterval: -> @_toMilliSeconds( @_conversionSettings?.speech?.repeat?.interval?.parsed ? @config.interval )
    getText: -> @_conversionSettings.text.parsed
    isStatic: -> @_conversionSettings.text.static
    getCache: -> @_conversionSettings.output.cache
    getOutputDevice: -> @_conversionSettings.output.device
    
    textToSpeech: (ttsSettings) =>
      return Promise.reject new Error( __("%s - TTS text provided is null or undefined.", @id) ) unless ttsSettings?.text?.parsed?
      
      @_setConversionSettings(ttsSettings)
      
      outputDevice  = @getOutputDevice()
      
      Promise.join(
        @_createSpeechResource( @getText() ),
        outputDevice.getType(),
        outputDevice.getState(),
        (resource, type, state) =>
          return Promise.reject new Error( __("Network media player %s was not detected. Unable to ouput speech.", outputDevice.id) ) unless state
          
          if type is 'localAudio'
            return @_outputAudio(outputDevice, resource, @getSessionVolume(), @getSessionRepeat(), @getSessionInterval()) 
          
          resource = 'imperial_march.mp3'
          @_startMediaServer(resource)
          .then( (url) =>
            return @_outputAudio(outputDevice, url, @getSessionVolume(), @getSessionRepeat(), @getSessionInterval())
          )
          .catch( (error) =>
            return Promise.reject error
          )
          .finally( () =>
            @_stopMediaServer()
          )
      )
      .catch( (error) =>
        @base.resetLastError()
        @base.error __("There were error(s) outputting text to speech")
        @base.stack(error) if @debug
        
        return Promise.reject error
      )
      
    _outputAudio: (device, resource, volume, iterations = 1, interval =0) =>
      text = @getText()
      
      mp3Duration(@getCache())
      .then( (duration) =>
        @_repeatOutput(device, resource, duration, volume, iterations, interval)
      )
      .then( (result) =>
        return Promise.resolve( __("'%s' was spoken %s times", text, iterations) )
      )
      .catch(Promise.AggregateError, (errors) =>
        return Promise.reject( new Error( __("'%s' was only spoken %s out of %s times.", text, ( iterations - errors.length ), iterations ) ) )
      )
      .catch( (error) =>
        return Promise.reject( error )
      )
      .finally( () =>
        if !@isStatic() or !@isCacheEnabled()
          @base.debug __("Static text: %s, Cache enabled: %s. Removing cached file: '%s'", @isStatic(), @isCacheEnabled(), @getCache())
          @_removeCache()
      )
    
    _repeatOutput: (device, resource, duration, volume, iterations, interval, i = 0, results = []) =>
      @base.debug __("Starting audio output for iteration: %s", i+1)
      
      done      = () => return ( iterations <= i )
      wait  = () => if done() then return @_toMilliSeconds(1) else return interval
      addResult = (result) -> results.push(result)
      
      device.playAudio(resource, duration, volume)
      .then( (result) => 
        addResult(result)
      )
      .catch( (error) =>
        @base.resetLastError()
        @base.error(error)
        @base.stack(error)
        addResult(error)
       )
      
      .delay( wait() )
      
      .finally( () =>
        i++
        return Promise.all(results) if done()
        
        repeater = @_outputWithDelayedRepeat(device, resource, duration, volume, iterations, interval, i, results)
      )
    
    _startMediaServer: (resource) =>
      @_mediaServer = new MediaServer({ port:0, address: @_mediaServerAddress}, @debug)
      @_mediaServer.create(resource)
    
    _stopMediaServer: () =>
      @_mediaServer.stop() if @_mediaServer?
    
    _createSpeechResource: (text, attempt = 1) =>
      @base.debug __("%s: Getting TTS Resource.", @id)
      
      return new Promise( (resolve, reject) =>
        fname = path.join(@getCacheDir(), @_createFilename(text))
        
        fs.open(fname, 'r', (error, fd) =>
          if error?
            if error.code is "ENOENT"
              env.logger.info("%s: Generating speech resource", @id)
              
              return @_synthesizeSpeech(fname, text).then( (file) => 
                @_setCache(file)
                resolve file
              )
              
            else
              if attempt < 4
                env.logger.warning __("%s: Cached resource cannot be accessed. Attempting to remove and re-create.", @id)
                
                attempt++
                @_removeCache()
                .finally( () => 
                  @_createSpeechResource(text, attempt)
                )
                
              else
                reject new Error( __("%s: Unable to remove file. Giving up.", @id) )
          
          else
            fs.close(fd, () =>
              env.logger.info __("%s: Using cached speech resource.", @id)
              
              @_setCache(fname)
              resolve fname
            )
        )
      )
    
    _createFileFromStream: ( readStream, file ) =>
      return new Promise( (resolve, reject) =>
        fsWrite = fs.createWriteStream(file)
          .on('finish', () =>
            
            fsWrite.close( () => 
              @base.debug __("file: %s", file)
              
              resolve file
            )
          )
          .on('error', (error) =>
            @base.resetLastError()
            
            @_removeCache()
            .then( () =>
              reject error
            )
            .catch( (error) =>
              reject error
            )
          )
        readStream.pipe(fsWrite)
      )
    
    _removeCache: (fname) =>
      fname ?= @getCache()
      
      return new Promise( (resolve, reject) =>  
        fs.open(fname, 'wx', (error, fd) =>
          
          if error?.code is "EEXIST"
            fs.unlink(fname, (error) =>
              
              if error
                reject error
              
              else
                @base.debug __("Deleted file: %s", fname)
                resolve true
            )
          else if error?
            @base.error __("Unable to delete file: %s", fname)
            reject error
        )
        fs.close(fd) if fd?
        resolve true
      )
    
    _toMilliSeconds: (time) -> 
      return time *1000
    
    _createHash: (value) ->
      md5 = Crypto.createHash('md5')
      return md5.update(value).digest('hex')
      
    _createFilename: () -> 
      return __("%s%s_%s.%s", @_FILE_PREFIX, @id, @_createHash( @getText() ), @getAudioFormat())
    
    _setCache: (value) ->
      if value is @_conversionSettings.output.cache then return
      @_conversionSettings.output.cache = value
      @emit 'resource', value
      
    _setConversionSettings: (settings) ->
      @_conversionSettings = settings
      @emit('conversionSettings', settings)
      
    _errMethodNotImplemented: (method) -> 
      throw new Error __("Method \"%s\" is not implemented!", method)
    
    _logError: (error) =>
      @base.resetLastError()
      @base.error(error.message) if typeof error is 'object'
        
    destroy: () ->
      @removeAllListeners('state')
      
      super()

  return TTSDevice