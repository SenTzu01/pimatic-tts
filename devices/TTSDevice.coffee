module.exports = (env) ->

  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  t = env.require('decl-api').types

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
      
      @_language = @config.language
      @_speed = @config.speed
      @_volume = @config.volume
      @_iterations = @config.repeat
      @_interval = @config.interval
      @_latestText = lastState?.resource?.value or ''
      @_latestResource = lastState?.resource?.value or ''
      
      @_repetitions = []
      
      super()
      
    convertToSpeech: (text, language, speed, volume, iterations, interval) =>
      return new Promise( (resolve, reject) =>
        @createSpeechResource(text, language, speed).then( (url) =>
          @repeatOutput(iterations, interval, volume).then( (result) =>
            resolve result
          )
        )
      )
      
    repeatOutput: (iterations, interval, volume) =>
      iterations ?= @_iterations
      interval ?= @_interval
      i = 1
      
      return new Promise( (resolve, reject) =>
        
        output = (volume) => @outputSpeech(volume).then( (result) => 
          @_addToSpeechOutResults(result)
          i++
        )
        output(volume)
        
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
          output(volume) if i <= iterations
          
          if i >= iterations
            return new Promise( (reolve, reject) =>
              stop(interval).then( (result) =>
                resolve result
              )
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
      if @_latestText is value then return
      @_latestText = value
      @emit 'latestText', value
      
    _setLatestResource: (value) ->
      if @_latestResource is value then return
      @_latestResource = value
      @emit 'latestResource', value
    
    destroy: () ->
      super()

  return TTSDevice