module.exports = (env) ->
  
  _ = env.require 'lodash'
  t = env.require('decl-api').types
  Promise = env.require 'bluebird'
  TTSDevice = require("./TTSDevice")(env)
  GoogleAPI = require('google-tts-api')
  Request = require('request')
  Lame = require('lame')
  fs = require('fs')
    
  class GoogleTTSDevice extends TTSDevice
    
    constructor: (@config, lastState) ->
      @id = @config.id
      @name = @config.name
      
      @_options = {
        speed: @config.speed ? 100
        audioDecoder: require('lame').Decoder
        audioFormat: 'mp3'
        maxStringLenght: 200
      }
      
      @actions = _.cloneDeep @actions
      @attributes =  _.cloneDeep @attributes
        
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
      
      super()
    
    getSpeed: -> Promise.resolve(@_options.speed)
    
    getTTS: () =>
      env.logger.debug __("%s: Getting TTS Resource for text: %s, language: %s, speed: %s", @id, @_data.text.parsed, @_options.language, @_options.speed)
      @base.rejectWithErrorString Promise.reject, __("%s: A maximum of 200 characters is allowed.", @id, @_data.text.parsed.length) unless @_data.text.parsed.length < @_options.maxStringLenght
      
      return new Promise( (resolve, reject) =>
        file = @_generateHashedFilename()
        
        fs.open(file, 'r', (error, fd) =>
          if error
            if error.code is "ENOENT"
              env.logger.debug("%s: Creating speech resource file '%s' using %s", @id, file, @_options.executable)
              
              env.logger.info("%s: Generating speech resource for '%s'", @id, @_data.text.parsed)
              
              #
              GoogleAPI(@_data.text.parsed, @_options.language, @_options.speed/100).then( (resource) =>
                
                fsWrite = fs.createWriteStream(file)
                  .on('finish', () =>
                    fsWrite.close( () => 
                      
                      env.logger.info __("%s: Speech resource for '%s' successfully generated.", @id, @_data.text.parsed)
                      resolve file
                    )
                  )
                  .on('error', (error) =>
                    fs.unlink(file)
                    @base.rejectWithErrorString Promise.reject, error
                  )
                
                resRead = Request.get(resource)
                  .on('error', (error) =>
                    msg = __("%s: Failure reading audio resource '%s'. Error: %s", @id, resource, error)
                    env.logger.debug msg
                    @base.rejectWithErrorString Promise.reject, msg
                  )
                resRead.pipe(fsWrite)
              
              ).catch( (error) => @base.rejectWithErrorString Promise.reject, error )
              #
              
            else
              # File exists but cannot be read, delete it, and reject with error
              env.logger.warning __("%s: %s already exists, but cannot be accessed. Attempting to remove. Error: %s", @id, file, error.code)
              @_removeResource(file)
              @base.rejectWithErrorString Promise.reject, error
          
          else
            fs.close(fd, () =>
              env.logger.debug __("%s: Speech resource for '%s' already exist. Reusing file.", @id, file)
              
              env.logger.info __("%s: Using cached speech resource for '%s'.", @id, @_data.text.parsed)
              resolve file
            )
        )
      ).catch( (error) => @base.rejectWithErrorString Promise.reject, error )
    
    destroy: () ->
      super()
  
  return GoogleTTSDevice