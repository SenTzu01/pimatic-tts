module.exports = (env) ->

  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  t = env.require('decl-api').types
  commons = require('pimatic-plugin-commons')(env)
  fs = require('fs')
  Crypto = require('crypto')
  Volume = require('pcm-volume')
  Speaker = require('speaker')
  
  class TTSDevice extends env.devices.Device
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
      getLanguage:
        description: "Returns the Voice synthesis language"
        returns:
          language:
            type: t.string
      getVolume:
        description: "Returns the gain volume applied on the audio output stream"
        returns:
          language:
            type: t.number
      getRepeat:
        description: "Returns the number of times the same message is repeated"
        returns:
          language:
            type: t.number
      getInterval:
        description: "Returns the amount of time between two repeats"
        returns:
          language:
            type: t.number
      toSpeech:
        description: "Converts Text-to-Speech and outputs Audio"
        params:
          text:
            type: t.object
      
    generateResource: () -> throw new Error "Function \"generateResource\" is not implemented!"
      
    constructor: () ->
      @base = commons.base @, @config.class
      
      @_options.language = @config.language ? 'en-GB'
      #@_options.volume = @config.volume ? 40
      #@_options.repeat = @config.repeat ? 1
      #@_options.interval = @config.interval ? 0
      @_options.tmpDir = @config.tmpDir ? '/tmp'
      @_options.enableCache = @config.enableCache ? true
      @_options.volume = { setting: @config.volume, max: 150, min: 1, maxRel: 100 }
      
      super()
      
    toSpeech: (ttsSettings) =>
      @_setConversionSettings(ttsSettings)
      
      return new Promise( (resolve, reject) =>
        repeat = @_conversionSettings.speech.repeat
        @base.rejectWithErrorString Promise.reject, __("%s - TTS text provided is null or undefined.", @config.id) unless @_conversionSettings?.text?.parsed?
        
        @_cacheResource().then( (resource) =>
          
          i = 0
          results = []
          playback = =>
            env.logger.debug __("%s: Starting audio output for iteration: %s", @id, i+1)
            
            @_speechOut().then( (result) =>
              env.logger.debug __("%s: Finished audio output for iteration: %s", @id, i+1)
              
              results.push result
              
              i++
              if i < repeat.number
                setTimeout(playback, repeat.interval*1000)
              
              else
                if !@_conversionSettings.text.static or !@_options.enableCache
                  env.logger.debug __("%s: Static text: %s, Cache enabled: %s. Removing cached file: '%s'", @id, @_conversionSettings.text.static, @_options.enableCache, resource)
                  @_removeCache()
                
                @emit('state', false)
                
                Promise.all(results).then( (result) =>
                  resolve __("'%s' was spoken %s times", @_conversionSettings.text.parsed, repeat.number)
                
                ).catch(Promise.AggregateError, (error) =>
                  reject __("'%s' was NOT spoken %s times. Error: %s", @_conversionSettings.text.parsed, repeat.number, error)
                )
                
            ).catch( (error) =>
              @emit('state', false)
              @base.rejectWithErrorString Promise.reject, error
            )
          
          @emit('state', true)
          env.logger.debug __("@_conversionSettings.speech.repeat:", @_conversionSettings.speech.repeat)
          env.logger.debug __("@_conversionSettings.speech.interval:", @_conversionSettings.speech.interval)
          playback()
          
        ).catch( (error) => @base.rejectWithErrorString Promise.reject, error)
      ).catch( (error) => @base.rejectWithErrorString Promise.reject, error )
    
    setVolumeLevel: (volume) ->
      @_volControl?.setVolume(@_pcmVolume(volume))
    
    _speechOut:() =>
      return new Promise( (resolve, reject) =>
        
        audioDecoder = new @_options.audioDecoder()
        audioDecoder.on('format', (pcmFormat) =>
          env.logger.debug pcmFormat
          
          speaker = new Speaker(pcmFormat)
            .on('open', () =>
              env.logger.debug __("%s: Audio output of '%s' started.", @id, @_conversionSettings.text.parsed)
            )
        
            .on('error', (error) =>
              msg = __("%s: Audio output of '%s' failed. Error: %s", @id, @_conversionSettings.text.parsed, error)
              env.logger.debug msg
              @base.rejectWithErrorString Promise.reject, error
            )
        
            .on('finish', () =>
              msg = __("%s: Audio output of '%s' completed successfully.", @id, @_conversionSettings.text.parsed)
              env.logger.debug msg
              resolve msg
            )
            
          env.logger.debug __("@_conversionSettings.speech.volume:", @_conversionSettings.speech.volume)
          @_volControl = new Volume(@_pcmVolume(@_conversionSettings.speech.volume))
          @_volControl.pipe(speaker)
          audioDecoder.pipe(@_volControl)
        )
        @getCache().then( (resource) =>
          fs.createReadStream(resource).pipe(audioDecoder)
        )
        
      ).catch( (error) => @base.rejectWithErrorString Promise.reject, error )
    
    _cacheResource: () =>
      env.logger.debug __("%s: Getting TTS Resource for text: '%s', language: '%s'", @id, @_conversionSettings.text.parsed, @_options.language)
      
      return new Promise( (resolve, reject) =>
        @_generateHashedFilename().then( @getCache()).then( (cache) =>
        
          fs.open(cache, 'r', (error, fd) =>
            if error
              if error.code is "ENOENT"
                env.logger.debug("%s: Creating speech resource cache: '%s' for text: %s ", @id, cache, @_conversionSettings.text.parsed)
                
                env.logger.info("%s: Generating speech resource for '%s'", @id, @_conversionSettings.text.parsed)
                
                return @generateResource(cache).then( (resource) => 
                  @_setResource(resource)
                  resolve resource
                ).catch( (error) => @base.rejectWithErrorString Promise.reject, error )
                
              else
                # Cache file exists but cannot be read, delete it, and reject with error
                env.logger.warning __("%s: Cached resource exists, but cannot be accessed. Attempting to remove. Error: %s", @id, error.code)
                @_removeCache()
                @base.rejectWithErrorString Promise.reject, error
            
            else
              fs.close(fd, () =>
                env.logger.debug __("%s: Speech resource for '%s' already exist. Reusing cache.", @id, cache)
                
                env.logger.info __("%s: Using cached speech resource for '%s'.", @id, @_conversionSettings.text.parsed)
                resolve cache
              )
          )
        )
      ).catch( (error) => @base.rejectWithErrorString Promise.reject, error )
    
    getLanguage: -> Promise.resolve(@_options.language)
    getTempDir: -> Promise.resolve(@_options.tmpDir)
    isCacheEnabled: -> Promise.resolve(@_options.enableCache)
    getVolume: -> Promise.resolve(@_conversionSettings?.speech?.volume)
    getRepeat: -> Promise.resolve(@_conversionSettings?.speech?.repeat?.number)
    getInterval: -> Promise.resolve(@_conversionSettings?.speech?.repeat?.interval)
    getText: -> Promise.resolve(@_conversionSettings?.text?.parsed)
    getStatic: -> Promise.resolve(@_conversionSettings?.text?.static)
    getResource: -> Promise.resolve(@_conversionSettings?.speech?.resource)
    getCache: -> Promise.resolve(@_conversionSettings?.speech?.cache)
    
    _setResource: (value) ->
      if value is @_conversionSettings.speech.resource then return
      @_conversionSettings.speech.resource = value
      @emit 'resource', value
    
    setVolume: (value) ->
      if value is @_conversionSettings.speech.volume then return
      @_conversionSettings.speech.volume = value
      @emit('volume', value)
    
    setRepeat: (value) ->
      if value is @_conversionSettings.speech.repeat.number then return
      @_conversionSettings.speech.repeat.number = value
      @emit('repeat', value)
    
    setIntervals: (value) ->
      if value is @_conversionSettings.speech.repeat.interval then return
      @_conversionSettings.speech.repeat.interval = value
      @emit('interval', value)
    
    _setConversionSettings: (settings) ->
      @_conversionSettings = settings
      @emit('conversionSettings', settings)
    
    _setCache: (value) ->
      if value is @_conversionSettings.speech.cache then return
      @_conversionSettings.speech.cache = value
      @emit 'cache', value
      
    _pcmVolume: () ->
      volume = @_conversionSettings?.speech?.volume ? 100
      if volume < @_options?.volume?.min then volume = @_options?.volume?.min ? 1 
      if volume > @_options?.volume?.max then volume = @_options?.volume?.max ? 100
      
      return (volume/@_options?.volume?.maxRel*@_options?.volume?.max/@_options?.volume?.maxRel).toPrecision(2)
      
    _generateHashedFilename: () -> 
      md5 = Crypto.createHash('md5')
      cache = @_options.tmpDir + '/pimatic-tts_' + @id + '_' + md5.update(@_conversionSettings.text.parsed).digest('hex') + '.' + @_options.audioFormat
      @_setCache(cache)
      return Promise.resolve cache
      
    _removeCache: () =>
      @getCache().then( (resource) =>
        fs.open(resource, 'wx', (error, fd) =>
          if error and error.code is "EEXIST"
            fs.unlink(resource, (error) =>
              if error
                env.logger.warn __("%s: Removing resource file '%s' failed. Please remove manually. Reason: %s", @id, resource, error.code)
                return error
            )
          return true
        )
      )
    
    destroy: () ->
      @removeAllListeners('state')
      
      super()

  return TTSDevice