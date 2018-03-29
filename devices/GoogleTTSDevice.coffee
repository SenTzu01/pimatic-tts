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
      env.logger.debug __("%s - text: %s, language: %s, speed: %s", @config.id, text, @_options.language, @_options.speed)
      
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
      
    #testing audio output
    outputSpeech:(resource) =>
      
      return new Promise( (resolve, reject) =>
        format = {}
        pcmDecoder = new Lame.Decoder()
        volControl = new Volume(@_pcmVolume(@_options.volume))
        
        env.logger.debug @_options
        
        Request
          .get(resource)
          .on('error', (error) =>
            env.logger.debug error
            reject error
          )
          .pipe(pcmDecoder)
        
        pcmDecoder.pipe(volControl)
        
        pcmDecoder.on('format', (format) =>
          env.logger.debug format
          
          speaker = new Speaker(format)
          
          volControl.pipe(speaker)
          volControl.setVolume(@_pcmVolume(@_options.volume))
          
          speaker.on('open', () =>
            env.logger.debug __("playback started")
          )
          
          speaker.on('error', (error) =>
              env.logger.debug error
              reject error
          )
          
          speaker.on('finish', () =>
            @_volControl = null
            env.logger.debug __("finished playback")
            resolve __("Text-to-Speech: '%s' outputted.", @_latestText)
          )
        )
      )
      
    destroy: () ->
      super()
  
  return GoogleTTSDevice
  
  
        