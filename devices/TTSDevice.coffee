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
      
    getTTS: () -> throw new Error "Function \"createSpeechResource\" is not implemented!"
      
    constructor: () ->
    
      @_options.language = @config.language ? 'en-GB'
      @_options.volume = @config.volume ? 40
      @_options.iterations = @config.repeat ? 1
      @_options.interval = @config.interval ? 0
      @_options.tmpDir = @config.tmpDir ? '/tmp'
      @_options.enableCache = @config.enableCache ? true

      @_data = null
      
      @base = commons.base @, @config.class
      
      super()
      
    toSpeech: (data) =>
      @_setData(data)
      
      return new Promise( (resolve, reject) =>
        @base.rejectWithErrorString Promise.reject, __("%s - TTS text provided is null or undefined.", @config.id) unless @_data?.text?.parsed?
        
        @getTTS().then( (resource) =>
          @_setResource(resource)
          
          i = 0
          results = []
          playback = =>
            env.logger.debug __("%s: Starting audio output for iteration: %s", @id, i+1)
            
            @_outputSpeech().then( (result) =>
              env.logger.debug __("%s: Finished audio output for iteration: %s", @id, i+1)
              
              results.push result
              
              i++
              if i < @_options.iterations
                setTimeout(playback, @_options.interval*1000)
              
              else
                if !@_data.text.static or !@_options.enableCache
                  env.logger.debug __("%s: Static text: %s, Cache enabled: %s. Removing cached file: '%s'", @id, @_data.text.static, @_options.enableCache, @_data.resource)
                  @_removeResource(@_data.resource)
                
                @emit('state', false)
                
                Promise.all(results).then( (result) =>
                  resolve __("'%s' was spoken %s times", @_data.text.parsed, @_options.iterations)
                
                ).catch(Promise.AggregateError, (error) =>
                  reject __("'%s' was NOT spoken %s times. Error: %s", @_data.text.parsed, @_options.iterations, error)
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
    
    _outputSpeech:() =>
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
          volControl = new Volume(@_pcmVolume(@_options.volume))
          volControl.pipe(speaker)
          audioDecoder.pipe(volControl)
        )
        streamData = fs.createReadStream(@_data.resource)
        streamData.pipe(audioDecoder)
        
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