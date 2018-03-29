module.exports = (env) ->

  Promise = env.require 'bluebird'
  TTSDevice = require("./TTSDevice")(env)
  GoogleAPI = require('google-tts-api')
  request = require('request')
  lame = require('lame')
  Speaker = require('speaker')
  
  class GoogleTTSDevice extends TTSDevice
    
    constructor: (@config, lastState) ->
      super(@config, lastState)
      
    createSpeechResource: (text) =>
      env.logger.debug __("%s - text: %s, language: %s, speed: %s", @config.id, text, @_options.language, @_options.speed)
      
      return new Promise( (resolve, reject) =>
        GoogleAPI(text, @_options.language, @_options.speed/100).then( (url) =>
          resolve url
        ).catch( (error) =>
          reject __("Error obtaining TTS resource: %s", error)
        )
      )
    
    #testing audio output
    outputSpeech:(resource) =>
      
      return new Promise( (resolve, reject) =>
        env.logger.debug __("Would play:  %s, volume: %s", resource, (@_options.volume/100).toPrecision(1))
        format = {}
        request
          .get(resource)
          .on('error', (error) =>
            env.logger.debug error
          )
          .pipe(new lame.Decoder())
          .on('format', (format) =>
            console.log(format)
          )
          .pipe(new Speaker(format))
          .on('error', (err) =>
              env.logger.debug err
          )
          .on('finish', () =>
            console.log("finished playback")
          )
        resolve true
      )
      
    destroy: () ->
      super()
  
  return GoogleTTSDevice
  
  
        