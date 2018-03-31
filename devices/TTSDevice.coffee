module.exports = (env) ->

  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  t = env.require('decl-api').types
  commons = require('pimatic-plugin-commons')(env)
  fs = require('fs')
  
  class TTSDevice extends env.devices.Device
    attributes:
      language:
        description: "Voice synthesis language"
        type: t.string
        acronym: 'Language:'
        discrete: true
      speed:
        description: "Voice speed"
        type: t.number
        acronym: 'Voice Speed:'
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
      getSpeed:
        description: "Returns the Voice speed"
        returns:
          speed:
            type: t.number
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
      convertToSpeech:
        description: "Converts Text-to-Speech and outputs Audio"
        params:
          text:
            type: t.string
      
    
    createSpeechResource: () ->
      throw new Error "Function \"createSpeechResource\" is not implemented!"
    
    outputSpeech: () ->
      throw new Error "Function \"outputSpeech\" is not implemented!"
      
    constructor: (@config, lastState) ->
      @id = @config.id
      @name = @config.name
      @_options = {
        language: @config.language ? 'en-GB'
        speed: @config.speed ? 100
        volume: @config.volume ? 40
        iterations: @config.repeat ? 1
        interval: @config.interval ? 0
      }
      
      @_latestText = null
      @_volatileText = false
      @_latestResource = null
      @_fileResource = null
      @_repetitions = []
      @base = commons.base @, 'Plugin'
      
      super()
      
    convertToSpeech: (data) =>
      reject __("%s - message: '%s', TTS text provided is null or undefined.", @config.id, data.message.parsed) unless data?.message?.parsed?
      @_setLatestText(data.message.parsed)
      @_setVolatileText(data.message.hasVars)
      
      return new Promise( (resolve, reject) =>
        @createSpeechResource(data.message).then( (resource) =>
          @_setLatestResource(resource)
          
          i = 0
          results = []
          playback = =>
            env.logger.debug __("%s: Starting audio output for iteration: %s", @id, i+1)
            
            @outputSpeech(resource).then( (result) =>
              results.push result
              env.logger.debug __("%s: Finished audio output for iteration: %s", @id, i+1)
              i++
              
              if i < @_options.iterations
                setTimeout(playback, @_options.interval*1000)
              
              else
                @_removeResource(resource) if @_volatileText and @_fileResource?
                @emit('state', false)
                Promise.all(results).then( (result) =>
                  resolve __("'%s' was spoken %s times", @_latestText, @_options.iterations)
                
                ).catch(Promise.AggregateError, (error) =>
                  reject __("'%s' was NOT spoken %s times. Error: %s", @_latestText, @_options.iterations, error)
                )
            ).catch( (error) =>
              @emit('state', false)
              reject error
            )
          
          @emit('state', true)
          playback()
          
        ).catch( (error) =>
          reject __("Error while converting '%s' to speech: %s", @_latestText, error)
        )
      )
    
    setVolume: (value) ->
      if value is @_options.volume then return
      @_options.volume = value
      @emit('volume', value)
      
    _pcmVolume: (value) ->
      volMaxRel = 100
      volMaxAbs = 150
      return (value/volMaxRel*volMaxAbs/volMaxRel).toPrecision(2)
      
    getLanguage: -> Promise.resolve(@config.language)
    getSpeed: -> Promise.resolve(@config.speed)
    getVolume: -> Promise.resolve(@config.volume)
    getRepeat: -> Promise.resolve(@config.repeat)
    getInterval: -> Promise.resolve(@config.interval)
    getLatestText: -> Promise.resolve(@_latestText)
    
    _setLatestText: (value) ->
      if @_latestText is value then return
      @_latestText = value
      @emit 'latestText', value
    
    _setVolatileText: (value) ->
      if @_volatileText is value then return
      @_volatileText = value
      @emit 'volatileText', value
      
    _setLatestResource: (value) ->
      if @_latestResource is value then return
      @_latestResource = value
      @emit 'latestResource', value
    
    _removeResource: (resource) =>
      env.logger.debug __("%s: TTS resource '%s' was created based on Pimatic variables. Removing cached file.", @id, resource)
      fs.open(resource, 'wx', (error, fd) =>
        if error and error.code is "EEXIST"
          fs.unlink(resource, (error) =>
            if error
              env.logger.warn __("%s: Removing resource file '%s' failed. Please remove manually. Reason: %s", @id, resource, error.code)
          )
      )
    
    destroy: () ->
      @removeAllListeners('active')
      
      super()

  return TTSDevice