module.exports = (env) ->

  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  t = env.require('decl-api').types
  commons = require('pimatic-plugin-commons')(env)

  class TTSDevice extends env.devices.Device
    attributes:
      language:
        description: "Voice synthesis language"
        type: t.string
        acronym: 'Language:'
        discrete: true
      speed:
        description: "Voice speed"
        type: t.string
        acronym: 'Voice Speed:'
        discrete: true
      latestResource:
        description: "Audio resource with synthesized text"
        type: t.string
        acronym: 'Audio resource:'
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
            type: t.string
      getLatestResource:
        description: "Returns the synthesized audio resource"
        returns:
          resource:
            type: t.string
    
    createSpeechResource: () ->
      throw new Error "Function \"createSpeechResource\" is not implemented!"
    
    outputSpeech: () ->
      throw new Error "Function \"outputSpeech\" is not implemented!"
      
    constructor: (@config, lastState) ->
      @id = @config.id
      @name = @config.name
      
      @_iterations = @config.repeat ? null
      @_interval = @config.interval ? null 
      @_latestText = lastState?.resource?.value or ''
      @_latestResource = lastState?.resource?.value or ''
      
      @_repetitions = []
      @base = commons.base @, 'Plugin'
      
      super()
      
    convertToSpeech: (text, language, speed, volume, iterations, interval) =>
      return new Promise( (resolve, reject) =>
        commons.base.rejectWithErrorString Promise.reject, __("%s - text: '%s', tts text provided is null or undefined.", @config.id, text) unless text?
        @_setLatestText(text)
        @createSpeechResource(text, language, speed).then( (resource) =>
          @_setLatestResource(resource)
          @repeatOutput(resource, iterations, interval, volume).then( (result) =>
            resolve result
          )
        )
      )
      
    repeatOutput: (resource, iterations, interval, volume) =>
      iterations ?= @_iterations
      interval ?= @_interval
      i = 1
      
      return new Promise( (resolve, reject) =>
        
        output = (resource, volume) => @outputSpeech(resource, volume).then( (result) => 
          @_addToSpeechOutResults(result)
          i++
        )
        output(resource, volume)
        
        stop = (interval) =>
          return new Promise( (resolve, reject) =>
            @_processOutput().then( (result) =>
              clearInterval(repeat)
              repeat = null
              @_clearSpeechOutResults()
              resolve result
            )
          )
          
        repeat = setInterval(( =>
          output(resource, volume) if i <= iterations
          
          if i >= iterations
            return stop(interval).then( (result) =>
              resolve result
            )
        ), interval*1000)
      )
    
    _addToSpeechOutResults: (value) ->
      @_repetitions.push value
      
    _clearSpeechOutResults: () ->
      @_repetitions = []
      
    _processOutput: () =>
      return new Promise( (resolve, reject) =>
        Promise.all(@_repetitions).then( (results) =>
          resolve __("'%s' was spoken %s times", @_latestText, @_iterations)
        ).catch(Promise.AggregateError, (err) =>
          @base.rejectWithErrorString Promise.reject, __("'%s' was NOT spoken %s times", @_latestText, @_iterations)
        )
      )
    
    getLanguage: -> Promise.resolve(@config.language)
    getSpeed: -> Promise.resolve(@config.speed)
    getVolume: -> Promise.resolve(@config.volume)
    getRepeat: -> Promise.resolve(@config.repeat)
    getInterval: -> Promise.resolve(@config.interval)
    getLatestText: -> Promise.resolve(@_latestText)
    getLatestResource: -> Promise.resolve(@_latestResource)
    
    _setLatestText: (value) ->
      env.logger.debug __("text: %s", value)
      if @_latestText is value then return
      @_latestText = value
      @emit 'latestText', value
      
    _setLatestResource: (value) ->
      env.logger.debug __("TTS resource: %s", value)
      if @_latestResource is value then return
      @_latestResource = value
      @emit 'latestResource', value
    
    destroy: () ->
      super()

  return TTSDevice