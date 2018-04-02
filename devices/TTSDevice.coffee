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
      @_options.volume = @config.volume ? 40
      @_options.repeat = @config.repeat ? 1
      @_options.interval = @config.interval ? 0
      @_options.tmpDir = @config.tmpDir ? '/tmp'
      @_options.enableCache = @config.enableCache ? true

      @_data = null
      
      super()
      
    toSpeech: (data) =>
      @_setData(data)
      
      return new Promise( (resolve, reject) =>
        @base.rejectWithErrorString Promise.reject, __("%s - TTS text provided is null or undefined.", @config.id) unless @_data?.text?.parsed?
        
        @cacheResource().then( (resource) =>
          @_setResource(resource)
          
          repeat = @_data.repeat ? @_options.repeat
          interval = (@_data.interval ? @_options.interval)*1000
          
          i = 0
          results = []
          playback = =>
            env.logger.debug __("%s: Starting audio output for iteration: %s", @id, i+1)
            
            @_speechOut().then( (result) =>
              env.logger.debug __("%s: Finished audio output for iteration: %s", @id, i+1)
              
              results.push result
              
              i++
              if i < repeat
                setTimeout(playback, interval)
              
              else
                if !@_data.text.static or !@_options.enableCache
                  env.logger.debug __("%s: Static text: %s, Cache enabled: %s. Removing cached file: '%s'", @id, @_data.text.static, @_options.enableCache, @_data.resource)
                  @_removeResource(@_data.resource)
                
                @emit('state', false)
                
                Promise.all(results).then( (result) =>
                  resolve __("'%s' was spoken %s times", @_data.text.parsed, repeat)
                
                ).catch(Promise.AggregateError, (error) =>
                  reject __("'%s' was NOT spoken %s times. Error: %s", @_data.text.parsed, repeat, error)
                )
                
            ).catch( (error) =>
              @emit('state', false)
              @base.rejectWithErrorString Promise.reject, error
            )
          
          @emit('state', true)
          playback()
          
        ).catch( (error) => @base.rejectWithErrorString Promise.reject, error)
      ).catch( (error) => @base.rejectWithErrorString Promise.reject, error )
    
    setVolume: (value) ->
      if value is @_options.volume then return
      @_options.volume = value
      @emit('volume', value)
      
    _pcmVolume: (value) ->
      volMaxRel = 100
      volMaxAbs = 150
      return (value/volMaxRel*volMaxAbs/volMaxRel).toPrecision(2)
    
    setVolumeLevel: (volume) ->
      @_volControl?.setVolume(@_pcmVolume(volume))
    
    _speechOut:() =>
      return new Promise( (resolve, reject) =>
        
        audioDecoder = new @_options.audioDecoder()
        audioDecoder.on('format', (pcmFormat) =>
          env.logger.debug pcmFormat
          
          speaker = new Speaker(pcmFormat)
            .on('open', () =>
              env.logger.debug __("%s: Audio output of '%s' started.", @id, @_data.text.parsed)
            )
        
            .on('error', (error) =>
              msg = __("%s: Audio output of '%s' failed. Error: %s", @id, @_data.text.parsed, error)
              env.logger.debug msg
              @base.rejectWithErrorString Promise.reject, error
            )
        
            .on('finish', () =>
              msg = __("%s: Audio output of '%s' completed successfully.", @id, @_data.text.parsed)
              env.logger.debug msg
              resolve msg
            )
          @_volControl = new Volume(@_pcmVolume(@_data.volume ? @_options.volume))
          @_volControl.pipe(speaker)
          audioDecoder.pipe(@_volControl)
        )
        streamData = fs.createReadStream(@_data.resource)
        streamData.pipe(audioDecoder)
        
      ).catch( (error) => @base.rejectWithErrorString Promise.reject, error )
    
    cacheResource: () =>
      env.logger.debug __("%s: Getting TTS Resource for text: %s, language: %s, speed: %s", @id, @_data.text.parsed, @_options.language, @_options.speed)
      
      return new Promise( (resolve, reject) =>
        file = @_generateHashedFilename()
        
        fs.open(file, 'r', (error, fd) =>
          if error
            if error.code is "ENOENT"
              env.logger.debug("%s: Creating speech resource file: '%s' for text: %s ", @id, file, @_data.text.parsed)
              
              env.logger.info("%s: Generating speech resource for '%s'", @id, @_data.text.parsed)
              
              return @generateResource(file)
                .then( (resource) => resolve resource)
                .catch( (error) => @base.rejectWithErrorString Promise.reject, error )
              
            else
              # File exists but cannot be read, delete it, and reject with error
              env.logger.warning __("%s: %s already exists, but cannot be accessed. Attempting to remove. Error: %s", @id, file, error.code)
              @_removeResource(file)
              @base.rejectWithErrorString Promise.reject, error
          
          else
            fs.close(fd, () =>
              env.logger.debug __("%s: Speech resource for '%s' already exist. Reusing file.", @id, file)
              
              env.logger.info __("%s: Using cached speech resource for '%s'.", @id, @_data.text.parsed)
              resolve file
            )
        )
      ).catch( (error) => @base.rejectWithErrorString Promise.reject, error )
    
    getLanguage: -> Promise.resolve(@_options.language)
    getVolume: -> Promise.resolve(@_options.volume)
    getRepeat: -> Promise.resolve(@_options.repeat)
    getInterval: -> Promise.resolve(@_options.interval)
    getText: -> Promise.resolve(@_data.text.parsed)
    getStatic: -> Promise.resolve(@_data.text.static)
    getResource: -> Promise.resolve(@_data.resource)
    
    _setData: (obj) ->
      @_data = obj
      @emit('data', obj)
    
    _setResource: (value) ->
      if @_data.resource is value then return
      @_data.resource = value
      @emit 'resource', value
    
    _generateHashedFilename: () -> 
      md5 = Crypto.createHash('md5')
      @_data.fileName = @_options.tmpDir + '/pimatic-tts_' + @id + '_' + md5.update(@_data.text.parsed).digest('hex') + '.' + @_options.audioFormat
      return @_data.fileName
      
    _removeResource: (resource) =>
      fs.open(resource, 'wx', (error, fd) =>
        if error and error.code is "EEXIST"
          fs.unlink(resource, (error) =>
            if error
              env.logger.warn __("%s: Removing resource file '%s' failed. Please remove manually. Reason: %s", @id, resource, error.code)
              return error
          )
        return true
      )
    
    destroy: () ->
      @removeAllListeners('state')
      
      super()

  return TTSDevice