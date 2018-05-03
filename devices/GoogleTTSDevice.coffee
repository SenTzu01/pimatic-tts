module.exports = (env) ->
  
  _ = env.require 'lodash'
  commons = require('pimatic-plugin-commons')(env)
  t = env.require('decl-api').types
  Promise = env.require 'bluebird'
  googleAPI = require('google-tts-api')
  request = require('request')
  lame = require('lame')
  fs = require('fs')
  TTSDevice = require("./TTSDevice")(env)
  
  class GoogleTTSDevice extends TTSDevice
    
    constructor: (@config, lastState, @pluginConfig) ->
      @id = @config.id
      @name = @config.name
      
      @maxStringLenghtGoogle = 200
      @actions = _.cloneDeep @actions
      @attributes = _.cloneDeep @attributes
      
      @addAction('getSpeed', {
        description: "Returns the Voice speed"
        returns:
          speed:
            type: t.number})
      
      @addAttribute('speed',{
        description: "Voice speed"
        type: t.number
        acronym: 'Voice Speed:'
        discrete: true})
      
      
      super()
    
    _setup: ->
      @_setAudioFormat('mp3')
      @_setAudioDecoder( lame.Decoder )
      @_setSpeed(@config.speed)
      @_setMaxStringLength(@maxStringLenghtGoogle)
      
    getSpeed: -> @_options.speed
    getSpeedPercentage: -> @getSpeed() / 100
    getMaxStringLength: -> @_options.maxStringLength
    
    generateResource: (file, text) =>
      
      return new Promise( (resolve, reject) =>
        @base.rejectWithErrorString Promise.reject, new Error( __("%s: A maximum of 200 characters is allowed.", @id, text.length) ) unless text.length < @getMaxStringLength()
        
        @getLanguage().then( (language) =>
          @base.debug __("@_options.language: %s", language)
          @base.debug __("speed: %s. Calculated speed: %s", @getSpeed(), @getSpeedPercentage() )
          
          googleAPI( text, language, @getSpeedPercentage() ).then( (resource) =>
            @base.debug __("resource: %s", resource)
            
            readStream = request.get(resource)
              .on('error', (error) =>
                @base.rejectWithErrorString Promise.reject, error, __("Failure reading audio resource '%s'.", resource)
              )
            @_writeResource(readStream, file).then( (file) =>
              resolve file
            )
          )
        )
      )
    
    _setSpeed: (value) ->
      if value is @_options.speed then return
      @_options.speed = value
      @emit 'speed', value
    
    _setMaxStringLength: (value) ->
      if value is @_options.maxStringLenght then return
      @_options.maxStringLength = value
      @emit 'maxStringLength', value
    
    destroy: () ->
      super()
  
  return GoogleTTSDevice