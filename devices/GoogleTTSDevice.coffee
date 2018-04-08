module.exports = (env) ->
  
  _ = env.require 'lodash'
  commons = require('pimatic-plugin-commons')(env)
  t = env.require('decl-api').types
  Promise = env.require 'bluebird'
  googleAPI = require('google-tts-api')
  request = require('request')
  lame = require('lame')
  fs = require('fs')
  TTSDevice = require("./TTSDevice")(env)
  
  class GoogleTTSDevice extends TTSDevice
    
    constructor: (@config, lastState) ->
      @id = @config.id
      @name = @config.name
      
      @actions = _.cloneDeep @actions
      @attributes = _.cloneDeep @attributes
      
      @addAction('getSpeed', {
        description: "Returns the Voice speed"
        returns:
          speed:
            type: t.number})
      
      @addAttribute('speed',{
        description: "Voice speed"
        type: t.number
        acronym: 'Voice Speed:'
        discrete: true})
      
      super()
    
    _setup: ->
      @_setAudioFormat('mp3')
      @_setAudioDecoder(lame.Decoder)
      @_setSpeed(@config.speed)
      @_setMaxStringLength(200)
      
    getSpeed: -> Promise.resolve(@_options.speed)
    
    generateResource: (file, text) =>
      
      return new Promise( (resolve, reject) =>
        env.logger.debug __("@_conversionSettings.text.parsed.length: %s", text.length)
        @base.rejectWithErrorString Promise.reject, __("%s: A maximum of 200 characters is allowed.", @id, @_conversionSettings.text.parsed.length) unless text.length < @_options.maxStringLenght
        
        env.logger.debug __("@_options.language: %s", @_options.language)
        @getSpeed().then( (speed) =>
          env.logger.debug __("@_options.speed: %s. Calculated speed: %s", @_options.speed, @_options.speed/100)
          googleAPI(text, @_options.language, @_options.speed/100).then( (resource) =>
            env.logger.debug __("resource: %s", resource)
            
            resRead = request.get(resource)
              .on('error', (error) =>
                msg = __("%s: Failure reading audio resource '%s'. Error: %s", @id, resource, error)
                env.logger.debug msg
                @base.rejectWithErrorString Promise.reject, msg
              )
              
            fsWrite = fs.createWriteStream(file)
              .on('finish', () =>
                fsWrite.close( () => 
                        
                  env.logger.info __("%s: Speech resource for '%s' successfully generated.", @id, text)
                  env.logger.debug __("file: %s", file)
                  resolve file
                )
              )
              .on('error', (error) =>
                fs.unlink(file)
                @base.rejectWithErrorString Promise.reject, error
              )
            resRead.pipe(fsWrite)
          )
        ).catch( (error) => @base.rejectWithErrorString Promise.reject, error )
      ).catch( (error) => @base.rejectWithErrorString Promise.reject, error )
    
    _setSpeed: (value) ->
      if value is @_options.speed then return
      @_options.speed = value
      @emit 'speed', value
    
    _setMaxStringLength: (value) ->
      if value is @_options.maxStringLenght then return
      @_options.maxStringLength = value
      @emit 'maxStringLength', value
    

    destroy: () ->
      super()
  
  return GoogleTTSDevice