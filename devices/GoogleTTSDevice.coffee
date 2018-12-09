module.exports = (env) ->
  
  _ = env.require 'lodash'
  commons = require('pimatic-plugin-commons')(env)
  t = env.require('decl-api').types
  Promise = env.require 'bluebird'
  googleAPI = require('google-tts-api')
  request = require('request')
  fs = require('fs')
  TTSDevice = require("./TTSDevice")(env)
  lame = require('lame')
  textToSpeech = require('google-tts-api')
  SSML = require('ssml-builder')
  
  class GoogleTTSDevice extends TTSDevice
    
    constructor: (@config, lastState, @pluginConfig) ->
      @id = @config.id
      @name = @config.name
      
      @maxStringLenghtGoogle = 200
      @actions = _.cloneDeep @actions
      @attributes = _.cloneDeep @attributes
      
      @_options = {}
      
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
      @_setSpeed(@config.speed)
      @_setMaxStringLength(@maxStringLenghtGoogle)
      
    getSpeed: -> @_options.speed
    getSpeedPercentage: -> @getSpeed() / 100
    getMaxStringLength: -> @_options.maxStringLength
    getAudioFormat: () -> return 'mp3'
    
    _synthesizeSpeech: (file, text) =>
      
      return new Promise( (resolve, reject) =>
        return reject new Error( __("%s: A maximum of 200 characters is allowed.", @id, text.length) ) unless text.length < @getMaxStringLength()
        
        @base.debug __("speed: %s. Calculated speed: %s", @getSpeed(), @getSpeedPercentage() )
        
        @getLanguage()
        .then( (language) =>
          @base.debug __("@_options.language: %s", language)
          @base.debug __("speed: %s. Calculated speed: %s", @getSpeed(), @getSpeedPercentage() )
          
          googleAPI( text, language, @getSpeedPercentage() )
        )
        .then( (resource) =>
          @base.debug __("resource: %s", resource)
          
          readStream = request.get(resource)
          readStream.on('error', (error) =>
            return reject error
          )
          
          @_createFileFromStream(readStream, file)
        )
        .then( (file) => #readStream
            
            resolve file
        )
        
        ###
        @getLanguage()
        .then( (language) =>
          @base.debug __("@_options.language: %s", language)
          
          client = new textToSpeech.TextToSpeechClient()
          response = client.synthesizeSpeech({
            input: { 
              ssml: text
            },
            voice: {
              languageCode: language, 
              ssmlGender: 'FEMALE' 
            },
            audioConfig: {
              audioEncoding: 'MP3',
              speakingRate: @getSpeedPercentage()
            }
          })
          
          @base.debug(response)
          return response
        )
        .then( (response) =>
          @base.debug __("response: %s", response)
          
          @_createFileFromStream(response.audioContent, file)
        )
        .then( (file) =>
          resolve(file)
        )
        .catch( (error) =>
          reject(error)
        )
        ###
        
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