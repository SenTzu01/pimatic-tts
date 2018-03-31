module.exports = (env) ->

  Promise = env.require 'bluebird'
  TTSDevice = require("./TTSDevice")(env)
  Wav = require('wav')
  Volume = require('pcm-volume')
  Speaker = require('speaker')
  Crypto = require('crypto')
  spawn = require('child_process').spawn
  fs = require('fs')
  
  # sudo apt-get install libttspico0 libttspico-utils libttspico-data alsa-utils
  
  class PicoTTSDevice extends TTSDevice
    
    constructor: (@config, lastState) ->
      super(@config, lastState)
      @_options.tmpDir = @config.tmpDir ? '/tmp'
      @_options.executable = @config.executable ? 'pico2wav'
      
    createSpeechResource: (text) =>
      env.logger.debug __("%s: Getting TTS Resource for text: %s, language: %s", @id, text, @_options.language)
      
      return new Promise( (resolve, reject) =>
        md5 = Crypto.createHash('md5')
        file = @_options.tmpDir + '/' + md5.update(text).digest('hex') + '.wav'
        
        fs.open(file, 'r', (error, fd) =>
          if (error)
            if (error.code is "ENOENT")
              # file does not exist. create voice file
              args = [ '-l', @_options.language, '-w', file, text]
              
              pico = spawn(@_options.executable, args)
                .stdout.on( 'data', (data) =>
                  env.logger.debug __("%s output: %s", @_options.executable, data)
                
                )
                .stderr.on('data', (error) =>
                  env.logger.error __("Error creating speech resource '%s' using %s. Error: %s", text, @_options.executable, error)
                
                )
                .on('close', (code) =>
                  if (code is 0)
                    env.logger.debug __("Completed creating speech resource '%s' using %s.", text, @_options.executable)
                    resolve file
                  
                  else
                    msg = __("Error creating speech resource '%s' using %s. Error: %s", text, @_options.executable, code)
                    env.logger.error msg
                    reject msg
                
                )
            else
              # something else is wrong. file exists but cannot be read
              # need to handle this appropriately
              reject __("%s: %s already exists, but there is an error accessing it. Error: %s", @id, file, error.code)
          
          # return filename as it already is available
          resolve file
        )
      ).catch( (error) =>
        reject __("Error obtaining TTS resource: %s", error)
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

        streamWav = new Wav.Reader()
          .on('format', (pcmFormat) =>
            env.logger.debug pcmFormat
            
            speaker = new Speaker(pcmFormat)
              .on('open', () =>
                env.logger.debug __("TTS: Audio output of '%s' started.", @_latestText)
              )
          
              .on('error', (error) =>
                msg = __("TTS: Audio output of '%s' failed. Error: %s", @_latestText, error)
                env.logger.debug msg
                reject msg
              )
          
              .on('finish', () =>
                msg = __("TTS: Audio output of '%s' completed successfully.", @_latestText)
                env.logger.debug msg
                resolve msg
              )
            volControl = new Volume(@_pcmVolume(@_options.volume))
            volControl.pipe(speaker)
            streamWav.pipe(volControl)
          )
        streamData = fs.createReadStream(resource)
        streamData.pipe(streamWav)
      )
      
    destroy: () ->
      super()
  
  return PicoTTSDevice
  
  
        