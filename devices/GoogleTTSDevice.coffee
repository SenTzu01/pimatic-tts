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
      
      @actions.getSpeed = {
        description: "Returns the Voice speed"
        returns:
          speed:
            type: t.number}
      
      @attributes.speed = {
        description: "Voice speed"
        type: t.number
        acronym: 'Voice Speed:'
        discrete: true}
        
      @_options = {
        speed: @config.speed ? 100
        audioDecoder: lame.Decoder
        audioFormat: 'mp3'
        maxStringLenght: 200
      }

      super()
    
    getSpeed: -> Promise.resolve(@_options.speed)
    
    generateResource: (file) =>
      
      return new Promise( (resolve, reject) =>
        env.logger.debug __("@_conversionSettings.text.parsed.length: %s", @_conversionSettings.text.parsed.length)
        @base.rejectWithErrorString Promise.reject, __("%s: A maximum of 200 characters is allowed.", @id, @_conversionSettings.text.parsed.length) unless @_conversionSettings.text.parsed.length < @_options.maxStringLenght
        
        env.logger.debug __("@_options.language: %s", @_options.language)
        env.logger.debug __("@_options.speed: %s. Calculated speed: %s", @_options.speed, @_options.speed/100)
        googleAPI(@_conversionSettings.text.parsed, @_options.language, @_options.speed/100).then( (resource) =>
          env.logger.debug __("resource: %s", resource)
          fsWrite = fs.createWriteStream(file)
            .on('finish', () =>
              fsWrite.close( () => 
                      
                env.logger.info __("%s: Speech resource for '%s' successfully generated.", @id, @_conversionSettings.text.parsed)
                env.logger.debug __("file: %s", file)
                resolve file
              )
            )
            .on('error', (error) =>
              fs.unlink(file)
              @base.rejectWithErrorString Promise.reject, error
            )
          
          resRead = request.get(resource)
            .on('error', (error) =>
              msg = __("%s: Failure reading audio resource '%s'. Error: %s", @id, resource, error)
              env.logger.debug msg
              @base.rejectWithErrorString Promise.reject, msg
            )
          resRead.pipe(fsWrite)
              
        ).catch( (error) => @base.rejectWithErrorString Promise.reject, error )
      ).catch( (error) => @base.rejectWithErrorString Promise.reject, error )
    
    destroy: () ->
      super()
  
  return GoogleTTSDevice