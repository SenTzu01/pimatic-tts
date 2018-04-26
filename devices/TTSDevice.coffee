module.exports = (env) ->

  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  t = env.require('decl-api').types
  commons = require('pimatic-plugin-commons')(env)
  fs = require('fs')
  Crypto = require('crypto')
  Volume = require('pcm-volume')
  Speaker = require('speaker')
  MediaServer = require('../lib/DlnaMediaServer')(env)
  
  
  class TTSDevice extends env.devices.Device
    attributes:
      language:
        description: "Voice synthesis language"
        type: t.string
        acronym: 'Language:'
        discrete: true
      volume:
        description: "Voice volume"
        type: t.number
        acronym: 'Volume:'
        discrete: true
      repeat:
        description: "Repeats of same message"
        type: t.number
        acronym: 'Repeat:'
        discrete: true
      interval:
        description: "Time between two repeats"
        type: t.number
        acronym: 'Interval:'
        discrete: true
    
    actions:
      getLanguageDefault:
        description: "Returns the Voice synthesis language"
        returns:
          language:
            type: t.string
      getVolumeDefault:
        description: "Returns the gain volume applied on the audio output stream"
        returns:
          volume:
            type: t.number
      getRepeatDefault:
        description: "Returns the number of times the same message is repeated"
        returns:
          repeat:
            type: t.number
      getIntervalDefault:
        description: "Returns the amount of time between two repeats"
        returns:
          interval:
            type: t.number
      textToSpeech:
        description: "Converts Text-to-Speech and outputs Audio"
        params:
          text:
            type: t.object
      playAudio:
        description: "Outputs Audio to the configured device"
        params:
          resource:
            type: t.string
      
    generateResource: () -> throw new Error "Function \"generateResource\" is not implemented!"
    _setup: () -> throw new Error "Function \"_setup\" is not implemented!"
    
    constructor: () ->
      @base = commons.base @, @config.class
      @_options = {}
      
      @_setLanguage(@config.language ? 'en-GB')
      @_setTempDir(@config.tmpDir ? '/tmp')
      @_setCacheEnabled(@config.enableCache ? true)
      @_options.volume = { setting: @config.volume, max: 150, min: 1, maxRel: 100 }
      
      @_mediaServer = null
      @_mediaServerAddress = @pluginConfig.address
      
      @_setup()
      super()
      
    textToSpeech: (ttsSettings) =>
      @_setConversionSettings(ttsSettings)
      
      return new Promise( (resolve, reject) =>
        ms = 1000
        text = @getText()
        interval = @getSessionInterval()
        repeat = @getSessionRepeat()
        outputDevice = @getOutputDevice()
        
        env.logger.debug __("text: %s interval: %s, repeat: %s", text, interval, repeat)
        @base.rejectWithErrorString Promise.reject, __("%s - TTS text provided is null or undefined.", @config.id) unless text?
        
        @_getResource(text).then( (resource) =>
          i = 0
          results = []
          
          playback = =>
            
            env.logger.debug __("%s: Starting audio output for iteration: %s", @id, i+1)
            
            outputDevice.playAudio(resource).then( (result) =>
              env.logger.debug __("%s: Finished audio output for iteration: %s", @id, i+1)
              
              results.push result
              
              i++
              if i < repeat
                setTimeout(playback, interval * ms)
              
              else
                if !@isStatic() or !@isCacheEnabled()
                  env.logger.debug __("%s: Static text: %s, Cache enabled: %s. Removing cached file: '%s'", @id, @isStatic(), @isCacheEnabled(), resource)
                  @_removeCache(resource)
                
                if @_mediaServer?
                  @_mediaServer.stop()
                  @_mediaServer = null
                  
                @emit('state', false)
                
                return Promise.all(results).then( (result) =>
                  resolve __("'%s' was spoken %s times", text, repeat)
                
                ).catch(Promise.AggregateError, (error) =>
                  reject __("'%s' was NOT spoken %s times. Error: %s", text, repeat, error)
                )
                
            ).catch( (error) =>
              @emit('state', false)
              @base.rejectWithErrorString Promise.reject, error
            )
          
          env.logger.debug __("%s: resource: %s", @id, resource)
          env.logger.debug __("@_conversionSettings.speech.repeat.number: %s", repeat)
          env.logger.debug __("@_conversionSettings.speech.repeat.interval: %s", interval)
          
          
          @emit('state', true)

          if outputDevice.type is 'upnp'
            
            outputDevice.getPresence().then( (presence) =>
              env.logger.debug __("presence: %s", presence)
              if !presence
                @base.error __("Network media player %s was not detected. Unable to ouput Text-to-Speech", outputDevice.id)
                resolve false
              
              @_mediaServer = new MediaServer({ port:0, address: @_mediaServerAddress})
              @_mediaServer.create(resource).then( (url) =>
                env.logger.debug __("url: %s", url)
                resource = url
                playback()
              ).catch( (error) => Promise.reject error )
            )
          
          else
            playback()
          
        ).catch( (error) => @base.rejectWithErrorString Promise.reject, error)
      ).catch( (error) => @base.rejectWithErrorString Promise.reject, error )
    
      
    _getResource: (text) =>
      env.logger.debug __("%s: Getting TTS Resource for text: '%s', language: '%s'", @id, text, @_options.language)
      
      return new Promise( (resolve, reject) =>
        @_getHashedFilename(text).then( (fname) =>
        
          fs.open(fname, 'r', (error, fd) =>
            if error
              if error.code is "ENOENT"
                env.logger.info("%s: Generating speech resource for '%s'", @id, text)
                
                return @generateResource(fname, text).then( (res) => 
                  @_setResource(res)
                  resolve res
                
                ).catch( (error) => @base.rejectWithErrorString Promise.reject, error )
                
              else
                env.logger.warning __("%s: Cached resource exists, but cannot be accessed. Attempting to remove. Error: %s", @id, error.code)
                
                @_removeCache(fname)
                @base.rejectWithErrorString Promise.reject, error
            else
              fs.close(fd, () =>
                env.logger.info __("%s: Using cached speech resource for '%s'.", @id, text)
                @_setResource(fname)
                resolve fname
              )
          )
        )
      ).catch( (error) => @base.rejectWithErrorString Promise.reject, error )
    
    _writeResource: ( readStream, file ) =>
      return new Promise( (resolve, reject) =>
        fsWrite = fs.createWriteStream(file)
          .on('finish', () =>
            fsWrite.close( () => 
                    
              env.logger.info __("%s: Speech resource for '%s' successfully generated.", @id, @getText())
              env.logger.debug __("file: %s", file)
              resolve file
            )
          )
          .on('error', (error) =>
            fs.unlink(file)
            @base.rejectWithErrorString Promise.reject, error
          )
        readStream.pipe(fsWrite)
      )
            
    playAudio: (resource) =>
      return new Promise( (resolve, reject) =>
        
        audioDecoder = @getAudioDecoder()
        audioDecoder.on('format', (pcmFormat) =>
          env.logger.debug pcmFormat
          
          speaker = new Speaker(pcmFormat)
            .on('open', () =>
              env.logger.debug __("%s: Audio output started.", @id)
            )
        
            .on('error', (error) =>
              msg = __("%s: Audio output of '%s' failed. Error: %s", @id, @getText(), error)
              env.logger.debug msg
              @base.rejectWithErrorString Promise.reject, error
            )
        
            .on('finish', () =>
              msg = __("%s: Audio output completed successfully.", @id)
              env.logger.debug msg
              resolve msg
            )
            
          @getVolume().then( (volume) =>
            env.logger.debug __("@_conversionSettings.speech.volume: %s", volume)
            @_volControl = new Volume( @_pcmVolume( volume ) )
            @_volControl.pipe(speaker)
            audioDecoder.pipe(@_volControl)
          )
        )
        
        fs.createReadStream(resource).pipe(audioDecoder)
        
      ).catch( (error) => @base.rejectWithErrorString Promise.reject, error )
        
      
    getInterval: -> Promise.resolve @config.interval
    getVolume: -> Promise.resolve @config.volume
    getRepeat: -> Promise.resolve @config.repeat
    getLanguage: -> Promise.resolve @config.language
    
    getTempDir: -> @config.tmpDir
    isCacheEnabled: -> @config.enableCache
    getSessionVolume: -> @_conversionSettings?.speech?.volume ? @config.volume
    getSessionRepeat: -> @_conversionSettings?.speech?.repeat?.number ? @config.repeat
    getSessionInterval: -> @_conversionSettings?.speech?.repeat?.interval ? @config.interval
    getMaxRelativeVolume: -> @_options.volume.maxRel
    getMaxVolume: -> @_options.volume.max
    getMinVolume: -> @_options.volume.min
    getText: -> @_conversionSettings.text.parsed
    isStatic: -> @_conversionSettings.text.static
    getResource: -> @_conversionSettings.speech.resource
    getAudioDecoder: -> new @_options.audioDecoder()
    getAudioFormat: -> @_options.audioFormat
    getOutputDevice: -> @_conversionSettings.output.device ? @
    
    _setAudioFormat: (value) ->
      if value is @_options.audioFormat then return
      @_options.audioFormat = value
      @emit 'audioFormat', value
      
    _setAudioDecoder: (value) ->
      if value is @_options.audioDecoder then return
      @_options.audioDecoder = value
      @emit 'audioDecoder', value
    
    _setLanguage: (value) ->
      if value is @_options.language then return
      @_options.language = value
      @emit 'language', value
    
    _setTempDir: (value) ->
      if value is @_options.tmpDir then return
      @_options.tmpDir = value
      @emit 'tmpDir', value
      
    _setCacheEnabled: (value) ->
      if value is @_options.enableCache then return
      @_options.enableCache = value
      @emit 'enableCache', value
      
    _setResource: (value) ->
      if value is @_conversionSettings.speech.resource then return
      @_conversionSettings.speech.resource = value
      @emit 'resource', value
    
    setVolumeLevel: (volume) ->
      @_volControl?.setVolume(@_pcmVolume(volume))
      
    setVolume: (value) ->
      if value is @_conversionSettings.speech.volume then return
      @_conversionSettings.speech.volume = value
      @emit('volume', value)
    
    setRepeat: (value) ->
      if value is @_conversionSettings.speech.repeat.number then return
      @_conversionSettings.speech.repeat.number = value
      @emit('repeat', value)
    
    setIntervals: (value) ->
      if value is @_conversionSettings.speech.repeat.interval then return
      @_conversionSettings.speech.repeat.interval = value
      @emit('interval', value)
    
    _setConversionSettings: (settings) ->
      @_conversionSettings = settings
      @emit('conversionSettings', settings)
      
    
    _setVolumeWithinRange: (volume) ->
      if volume < @getMinVolume() then volume = @getMinVolume()
      if volume > @getMaxVolume() then volume = @getMaxVolume()
      return volume
      
    _pcmVolume: () -> return ( @_setVolumeWithinRange( @getVolume() ) / @getMaxRelativeVolume() * @getMaxVolume() / @getMaxRelativeVolume() ).toPrecision(2)
    
    _getHash: (value) ->
      md5 = Crypto.createHash('md5')
      return md5.update(value).digest('hex')
      
    _getHashedFilename: (text) ->
      fname = @getTempDir() + '/pimatic-tts_' + @id + '_' + @_getHash(text) + '.' + @getAudioFormat()
      return Promise.resolve fname
      
    _removeCache: (fname) => 
      fs.open(fname, 'wx', (error, fd) =>
        if error and error.code is "EEXIST"
          fs.unlink(fname, (error) =>
            if error
              env.logger.warn __("%s: Removing resource file '%s' failed. Please remove manually. Reason: %s", @id, fname, error.code)
              return error
          )
        return true
      )
    
    destroy: () ->
      @removeAllListeners('state')
      
      super()

  return TTSDevice