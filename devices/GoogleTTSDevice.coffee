module.exports = (env) ->

  Promise = env.require 'bluebird'
  TTSDevice = require("./TTSDevice")(env)
  GoogleAPI = require('google-tts-api')
  
  class GoogleTTSDevice extends TTSDevice
    
    constructor: (@config, lastState) ->
      @_language = @config.language ? null
      @_speed = @config.speed ? null
      @_volume = @config.volume ? null
      
      super(@config, lastState)
      
    createSpeechResource: (text, language, speed) =>
      language ?= @_language
      speed ?= @_speed
      
      env.logger.debug __("%s - text: %s, language: %s, speed: %s", @config.id, text, language, speed)
      
      return new Promise( (resolve, reject) =>
        GoogleAPI(text, language, speed/100).then( (url) =>
          resolve url
        ).catch( (error) =>
          commons.base.rejectWithErrorString Promise.reject, __("Error obtaining TTS resource: %s", error)
        )
      )
      
    outputSpeech:(resource, volume) =>
      volume ?= @_volume
      
      return new Promise( (resolve, reject) =>
        result = __("Stub: %s - AUDIO OUTPUT - %s with volume %s", @config.id, resource, (volume/100).toPrecision(1))
        env.logger.debug result
        resolve true
      ).catch( (error) =>
        commons.base.rejectWithErrorString Promise.reject, __("%s - Audio output error. Reason: %s", @config.id, error)
      )
      
    destroy: () ->
      super()
  
  return GoogleTTSDevice