module.exports = (env) ->

  Promise = env.require 'bluebird'
  TTSDevice = require("./TTSDevice")(env)
  GoogleAPI = require('google-tts-api')
  Request = require('request')
  Lame = require('lame')
  Volume = require('pcm-volume')
  Speaker = require('speaker')
  
  class GoogleTTSDevice extends TTSDevice
    
    constructor: (@config, lastState) ->
      super(@config, lastState)
      
    createSpeechResource: (text) =>
      env.logger.debug __("TTS: Getting TTS Resource for text: %s, language: %s, speed: %s", text, @_options.language, @_options.speed)
      
      return new Promise( (resolve, reject) =>
        GoogleAPI(text, @_options.language, @_options.speed/100).then( (url) =>
          resolve url
        ).catch( (error) =>
          reject __("Error obtaining TTS resource: %s", error)
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
      
    outputSpeech:(resource) =>
      
      return new Promise( (resolve, reject) =>
        format = {}
        pcmDecoder = new Lame.Decoder()
        volControl = new Volume(@_pcmVolume(@_options.volume))
        
        Request
          .get(resource)
          .on('error', (error) =>
            msg = __("TTS: Failure reading audio resource '%s'. Error: %s", resource, error)
            env.logger.debug msg
            reject msg
          )
          .pipe(pcmDecoder)
        
        pcmDecoder.pipe(volControl)
        
        pcmDecoder.on('format', (format) =>
          env.logger.debug format
          
          speaker = new Speaker(format)
          
          volControl.pipe(speaker)
          ### TEST
          setTimeout(( =>
            env.logger.debug __("setting volume to: %s", @_pcmVolume(@_options.volume-70))
            volControl.setVolume(@_pcmVolume(@_options.volume-70))
          ), 1000)
          ###
          
          speaker.on('open', () =>
            env.logger.debug __("TTS: Audio output of '%s' started.", @_latestText)
          )
          
          speaker.on('error', (error) =>
            msg = __("TTS: Audio output of '%s' failed. Error: %s", @_latestText, error)
            env.logger.debug msg
            reject msg
          )
          
          speaker.on('finish', () =>
            msg = __("TTS: Audio output of '%s' completed successfully.", @_latestText)
            env.logger.debug msg
            resolve msg
          )
        )
      )
      
    destroy: () ->
      super()
  
  return GoogleTTSDevice
  
  
        