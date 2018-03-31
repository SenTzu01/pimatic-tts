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
      @_fileResource = true
      
    createSpeechResource: (message) =>
      env.logger.debug __("%s: Getting TTS Resource for text: %s, language: %s", @id, message.parsed, @_options.language)
      return new Promise( (resolve, reject) =>
        md5 = Crypto.createHash('md5')
        file = @_options.tmpDir + '/' + md5.update(message.parsed).digest('hex') + '.wav'
        
        fs.open(file, 'r', (error, fd) =>
          if error
            if error.code is "ENOENT"
              # file does not exist. create voice file
              env.logger.debug("%s: Creating speech resource file '%s' using %s", @id, file, @_options.executable)
              args = [ '-l', @_options.language, '-w', file, message.parsed]
              
              pico = spawn(@_options.executable, args)
              pico.stdout.on( 'data', (data) =>
                env.logger.debug __("%s output: %s", @_options.executable, data)
              
              )
              pico.stderr.on('data', (error) =>
                env.logger.error __("%s: Error(s) encountered while creating speech resource '%s' using %s. Error: %s", @id, message.parsed, @_options.executable, error)
              
              )
              pico.on('close', (code) =>
                if (code is 0)
                  env.logger.debug __("%s: Completed creating speech resource for '%s'.", @id, message.parsed)
                  resolve file
                
                else
                  msg = __("%s: Error creating speech resource for '%s' using %s. Error: %s", @id, message.parsed, @_options.executable, code)
                  env.logger.error msg
                  reject msg
              
              )
              
            else
              # something else is wrong. file exists but cannot be read
              env.logger.warning __("%s: %s already exists, but cannot be accessed. Attempting to remove. Error: %s", @id, file, error.code)
              @_removeResource(file)
              @createSpeechResource(message)
              
          else
            fs.close(fd, () =>
              # return filename as it already is available
              env.logger.debug __("%s: Speech resource file '%s' already exist. Reusing file.", @id, file)
              resolve file
            )
        )
      ).catch( (error) =>
        reject __("Error obtaining TTS resource: %s", error)
      )
    
    outputSpeech:(resource) =>
      return new Promise( (resolve, reject) =>
        
        audioDecoder = new Wav.Reader()
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
        streamData = fs.createReadStream(resource)
        streamData.pipe(audioDecoder)
      )
      
    destroy: () ->
      super()
  
  return PicoTTSDevice
  
  
        