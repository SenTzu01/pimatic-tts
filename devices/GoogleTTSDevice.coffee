module.exports = (env) ->

  Promise = env.require 'bluebird'
  commons = require('pimatic-plugin-commons')(env)
  TTSDevice = require("./TTSDevice")(env)
  GoogleAPI = require('google-tts-api')
  
  class GoogleTTSDevice extends TTSDevice
    
    constructor: (@config, lastState) ->
      super(@config, lastState)
    
    createSpeechResource: (text, language, speed) =>
      language ?= @_language
      speed ?= @_speed
      
      env.logger.debug __("Plugin::toSpeech - text: %s, language: %s, speed: %s", text, language, speed)
      
      @_setLatestText(text)
      return new Promise( (resolve, reject) =>
        return commons.base.rejectWithErrorString Promise.reject, __("string provided is null or undefined") if !text?
        
        GoogleAPI(text, language, speed/100).then( (url) =>
          @_setLatestResource(url)
          resolve url
        ).catch( (error) =>
          commons.base.rejectWithErrorString Promise.reject, __("Error obtaining TTS resource: %s", error)
        )
      )
      
    outputSpeech:(volume) =>
      volume ?= @_volume
      
      return new Promise( (resolve, reject) =>
        result = __("Stub: AUDIO OUTPUT - %s with volume %s", @_latestResource, (volume/100).toPrecision(1))
        env.logger.debug result
        resolve result
      ).catch( (error) =>
        commons.base.rejectWithErrorString Promise.reject, __("Audio output error: %s", error)
      )
      
    destroy: () ->
      super()
  
  return GoogleTTSDevice