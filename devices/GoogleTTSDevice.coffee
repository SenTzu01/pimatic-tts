module.exports = (env) ->

  Promise = env.require 'bluebird'
  TTSDevice = require("./TTSDevice")(env)
  GoogleAPI = require('google-tts-api')
  Request = require('request')
  Lame = require('lame')
  Volume = require('pcm-volume')
  Speaker = require('speaker')
  fs = require('fs')
  Crypto = require('crypto')
    
  class GoogleTTSDevice extends TTSDevice
    
    constructor: (@config, lastState) ->
      super(@config, lastState)
      @_options.tmpDir = @config.tmpDir ? '/tmp'
      @_fileResource = true
      
    createSpeechResource: (message) =>
      maxLengthGoogle = 200
      
      env.logger.debug __("%s: Getting TTS Resource for text: %s, language: %s, speed: %s", @id, message.parsed, @_options.language, @_options.speed)
      return new Promise( (resolve, reject) =>
        reject __("'%s' is %s characters. A maximum of 200 characters is allowed.", message.parsed, message.parsed.length) unless message.parsed.length < maxLengthGoogle
        
        md5 = Crypto.createHash('md5')
        file = @_options.tmpDir + '/' + md5.update(message.parsed).digest('hex') + '.mp3'
        
        fs.open(file, 'r', (error, fd) =>
          if error
            if error.code is "ENOENT"
              # file does not exist. create voice file
              env.logger.debug("%s: Creating speech resource file '%s'", @id, file)
              GoogleAPI(message.parsed, @_options.language, @_options.speed/100).then( (url) =>
                
                fsWrite = fs.createWriteStream(file)
                fsWrite.on('finish', () =>
                  fsWrite.close( () => resolve file )
                )
                fsWrite.on('error', (err) =>
                  fs.unlink(file)
                  reject(err)
                )
                
                resRead = Request.get(url)
                resRead.on('error', (error) =>
                  msg = __("%s: Failure reading audio resource '%s'. Error: %s", @id, url, error)
                  env.logger.debug msg
                  reject msg
                )
                resRead.pipe(fsWrite)
              
              ).catch( (error) =>
                reject __("Error obtaining TTS resource: %s", error)
              )
              
            else
              # something else is wrong. file exists but cannot be read
              env.logger.warning __("%s: %s already exists, but cannot be accessed. Attempting to remove. Error: %s", @id, file, error.code)
              @_removeResource(file)
              reject error
              
          else
            fs.close(fd, () =>
              # return filename as it already is available
              env.logger.debug __("%s: Speech resource file '%s' already exist. Reusing file.", @id, file)
              resolve file
            )
        )
      )
    
    outputSpeech:(resource) =>
      return new Promise( (resolve, reject) =>
        
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
        streamData = fs.createReadStream(resource)
        streamData.pipe(audioDecoder)
        
      )
      
    destroy: () ->
      super()
  
  return GoogleTTSDevice