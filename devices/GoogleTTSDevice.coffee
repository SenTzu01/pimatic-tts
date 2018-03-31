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
      
    createSpeechResource: (message) =>
      maxLengthGoogle = 200
      
      env.logger.debug __("%s: Getting TTS Resource for text: %s, language: %s, speed: %s", @id, message.parsed, @_options.language, @_options.speed)
      return new Promise( (resolve, reject) =>
        reject __("'%s' is %s characters. A maximum of 200 characters is allowed.", message.parsed, message.parsed.length) unless message.parsed.length < maxLengthGoogle
        GoogleAPI(message.parsed, @_options.language, @_options.speed/100).then( (url) =>
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
        
        audioDecoder = new Lame.Decoder()
          .on('format', (pcmFormat) =>
            env.logger.debug pcmFormat
            
            speaker = new Speaker(pcmFormat)
              .on('open', () =>
                env.logger.debug __("%s: Audio output of '%s' started.", @id, @_latestText)
              )
          
              .on('error', (error) =>
                msg = __("%s: Audio output of '%s' failed. Error: %s", @id, @_latestText, error)
                env.logger.debug msg
                reject msg
              )
          
              .on('finish', () =>
                msg = __("%s: Audio output of '%s' completed successfully.", @id, @_latestText)
                env.logger.debug msg
                resolve msg
              )
            volControl = new Volume(@_pcmVolume(@_options.volume))
            volControl.pipe(speaker)
            audioDecoder.pipe(volControl)
          )
          
        Request
          .get(resource)
          .on('error', (error) =>
            msg = __("%s: Failure reading audio resource '%s'. Error: %s", @id, resource, error)
            env.logger.debug msg
            reject msg
          )
          .pipe(audioDecoder)
      )
      
    destroy: () ->
      super()
  
  return GoogleTTSDevice
  
  
        