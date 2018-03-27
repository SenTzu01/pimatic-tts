module.exports = (env) ->

  Promise = env.require 'bluebird'
  TTSDevice = require("./TTSDevice")(env)
  GoogleAPI = require('google-tts-api')
  Player = require('player')
  
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
    
    #testing audio output
    outputSpeech:(resource, volume) =>
      volume ?= @_volume
      
      return new Promise( (resolve, reject) =>
        player = new Player(resource, {downloads: '/var/tmp'})
          .on('playing', (item) =>
            player.setVolume(volume)
          )
          .on('playend', (item) =>
            return new Promise( (resolve, reject) =>
              player = null
              msg = __("%s was played", resource)
              env.logger.debug msg
              resolve msg
            )
          )
          .on('error', (error) =>
            return new Promise( (resolve, reject) =>
              player = null
              if 'No next song was found' is error
                msg = __("%s was played", resource)
                env.logger.debug msg
                resolve msg
              else
                env.logger.error error
                reject error
          )
        )
      player.play()
        
        
      ).catch( (error) =>
        commons.base.rejectWithErrorString Promise.reject, __("%s - Audio output error. Reason: %s", @config.id, error)
      )
      
    destroy: () ->
      super()
  
  return GoogleTTSDevice
  
  
        