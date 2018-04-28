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
  path = require('path')
  
  
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
      @debug = @pluginConfig.debug
      
      @_options = {}
      @_options.volume = { setting: @config.volume, max: 150, min: 1, maxRel: 100 }
      
      @_mediaServer = null
      @_mediaServerAddress = @pluginConfig.address
      
      @_setup()
      super()
      
    textToSpeech: (ttsSettings) =>
      @_setConversionSettings(ttsSettings)
      return @base.rejectWithErrorString Promise.reject, new Error( __("%s - TTS text provided is null or undefined.", @config.id) ) unless @getText()?
      
      @_createResource( @getText() ).then( (resource) =>
        @base.debug __(" Going to speak '%s', Repeating: %s times, every %s seconds", resource, @getSessionRepeat(), @getSessionInterval())
        
        if @getOutputDevice().type is 'upnp'
          
          @getOutputDevice().getPresence().then( (presence) =>
            return base.rejectWithErrorString Promise.reject, new Error( __("Network media player %s was not detected. Unable to ouput speech", @getOutputDevice().id) ) if !presence
            
            @_mediaServer = new MediaServer({ port:0, address: @_mediaServerAddress})
            @_mediaServer.create(resource)
          )
          .then( (url) =>
            @_setResource(url)
            return @_outputSpeech()
          )
          .catch( (error) =>
            return Promise.reject error
          )
          .finally( () =>
            @_mediaServer.stop() if @_mediaServer?
          )
        
        else
          @_outputSpeech()
          .catch( (error) =>
            return Promise.reject error
          )
          
      ).catch( (error) =>
        @base.resetLastError()
        @base.stack(error)
        return Promise.reject error
      )
    
    _outputSpeech: () =>
      return new Promise( (resolve, reject) =>
        i = 1
        interval = @getSessionInterval()
        results = []
        outputWithDelayedRepeat = () =>
          @base.debug __("%s: Starting audio output for iteration: %s", @id, i)
          
          result = @getOutputDevice().playAudio( @getResource() )
          result.then( () =>
            @base.debug __("%s: Finished audio output for iteration: %s", @id, i)
            
            i++
            results.push(result)
            interval = 1 if i is @getSessionRepeat()
          )
          .delay( interval*1000 )
          .catch( (error) =>
            results.push(result)
            @base.resetLastError()
            @base.error(error.message)
            @base.stack(error) if @debug
          )
          .finally( () =>
            if i <= @getSessionRepeat()
              repeater = outputWithDelayedRepeat()
            else
              return Promise.all( results )
          )
       
        outputWithDelayedRepeat().then( (result) =>
          resolve( __("'%s' was spoken %s times", @getText(), @getSessionRepeat()) ) if result?
        )
        .catch(Promise.AggregateError, (errors) =>
          return base.rejectWithErrorString( Promise.reject, new Error( __("'%s' was only spoken %s out of %s times.", getText(), ( @getSessionRepeat - errors.length ), @getSessionRepeat() ) ) )
        )
        .finally( () =>
          if !@isStatic() or !@isCacheEnabled()
            @base.debug __("%s: Static text: %s, Cache enabled: %s. Removing cached file: '%s'", @id, @isStatic(), @isCacheEnabled(), @getCache())
            @_removeCache()
        )
      )
      
    _createResource: (text, attempt = 1) =>
      @base.debug __("%s: Getting TTS Resource for text: '%s', language: '%s'", @id, text, @config.language)
      
      return new Promise( (resolve, reject) =>
        fname = path.join(@getCacheDir(), @_getHashedFilename(text))
        
        fs.open(fname, 'r', (error, fd) =>
          if error
            if error.code is "ENOENT"
              env.logger.info("%s: Generating speech resource for '%s'", @id, text)
              
              return @generateResource(fname, text).then( (cacheFile) => 
                @_setCache(cacheFile)
                resolve cacheFile
              )
              
            else
              if attempt < 4
                if attempt is 1
                  env.logger.warning __("%s: Cached resource cannot be accessed. Attempting to remove and re-create.", @id)
                else
                  env.logger.warning __("%s: Removal attempt %s...", @id, attempt)
                
                attempt++
                @_removeCache().then( (resolve, reject) => @_createResource(text, attempt) )
                
              else
                @base.rejectWithErrorString Promise.reject, new Error( __("Unable to remove file.") ), __("%s: Giving up.", @id)
          
          else
            fs.close(fd, () =>
              env.logger.info __("%s: Using cached speech resource for '%s'.", @id, text)
              
              @_setCache(fname)
              resolve fname
            )
        )
      )
    
    _writeResource: ( readStream, file ) =>
      return new Promise( (resolve, reject) =>
        fsWrite = fs.createWriteStream(file)
          .on('finish', () =>
            
            fsWrite.close( () => 
              @base.debug __("file: %s", file)
              
              resolve file
            )
          )
          .on('error', (error) =>
            @base.resetLastError()
            return @base.rejectWithErrorString Promise.reject, error, __("Error generating speech resource")
            @_removeCache()
            .catch( (error) =>
              @base.resetLastError()
              @base.error __("Error removing cache file: %s", error.message)
            )
          )
        readStream.pipe(fsWrite)
      )
    
    playAudio: (resource) => @_localAudio(resource)
    _localAudio: (resource) =>
      return new Promise( (resolve, reject) =>
        
        audioDecoder = @getAudioDecoder()
        audioDecoder.on('format', (pcmFormat) =>
          @base.debug pcmFormat
          
          speaker = new Speaker(pcmFormat)
            .on('open', () =>
              @base.debug __("%s: Audio output started.", @id)
            )
        
            .on('error', (error) =>
              @base.resetLastError()
              @base.rejectWithErrorString Promise.reject, error, __("%s: Audio output of '%s' failed. Error: %s", @id, @getText(), error)
            )
        
            .on('finish', () =>
              msg = __("%s: Audio output completed successfully.", @id)
              @base.debug msg
              resolve msg
            )
            
          
          @base.debug __("@_conversionSettings.speech.volume: %s", @getSessionVolume())
          @_volControl = new Volume( @_pcmVolume( @getSessionVolume() ) )
          @_volControl.pipe(speaker)
          audioDecoder.pipe(@_volControl)
          
        )
        
        fs.createReadStream(resource).pipe(audioDecoder)
      )
    
    getInterval: -> Promise.resolve @config.interval
    getVolume: -> Promise.resolve @config.volume
    getRepeat: -> Promise.resolve @config.repeat
    getLanguage: -> Promise.resolve @config.language
    
    getCacheDir: -> @config.tmpDir
    isCacheEnabled: -> @config.enableCache
    getSessionVolume: -> @_conversionSettings?.speech?.volume?.parsed ? @config.volume
    getSessionRepeat: -> @_conversionSettings?.speech?.repeat?.number?.parsed ? @config.repeat
    getSessionInterval: -> @_conversionSettings?.speech?.repeat?.interval?.parsed ? @config.interval
    getMaxRelativeVolume: -> @_options.volume.maxRel
    getMaxVolume: -> @_options.volume.max
    getMinVolume: -> @_options.volume.min
    getText: -> @_conversionSettings.text.parsed
    isStatic: -> @_conversionSettings.text.static
    getResource: -> @_conversionSettings.speech.resource
    getCache: -> @_conversionSettings.output.cache
    getAudioDecoder: -> new @_options.audioDecoder()
    getAudioFormat: -> @_options.audioFormat
    getOutputDevice: -> @_conversionSettings.output.device ? @
    
    _setSessionInterval: (value) ->
      if value is @_conversionSettings.speech.repeat.interval.parsed then return
      @_conversionSettings.speech.repeat.interval.parsed = value
      @emit 'sessionInterval', value
      
    _setAudioFormat: (value) ->
      if value is @_options.audioFormat then return
      @_options.audioFormat = value
      @emit 'audioFormat', value
      
    _setAudioDecoder: (value) ->
      if value is @_options.audioDecoder then return
      @_options.audioDecoder = value
      @emit 'audioDecoder', value
      
    _setResource: (value) ->
      if value is @_conversionSettings.speech.resource then return
      @_conversionSettings.speech.resource = value
      @emit 'resource', value
    
    _setCache: (value) ->
      if value is @_conversionSettings.output.cache then return
      @_conversionSettings.output.cache = value
      @emit 'resource', value
    
    setVolumeLevel: (volume) ->
      @_volControl?.setVolume(@_pcmVolume(volume))
      
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
      fname = '/pimatic-tts_' + @id + '_' + @_getHash(text) + '.' + @getAudioFormat()
      return fname
      
    _removeCache: (fname) =>
      fname ?= @getCache()
      
      return new Promise( (resolve, reject) =>  
        fs.open(fname, 'wx', (error, fd) =>
          
          if error?.code is "EEXIST"
            
            fs.unlink(fname, (error) =>
              if error
                reject error
              
              else
                @base.debug __("Deleted file: %s", fname)
                resolve true
            )
          reject error if error?
        )
        fs.close(fd) if fd?
        resolve true
      )
    
    destroy: () ->
      @removeAllListeners('state')
      
      super()

  return TTSDevice