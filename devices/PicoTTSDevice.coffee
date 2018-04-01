module.exports = (env) ->
  _ = env.require 'lodash'
  Promise = env.require 'bluebird'
  TTSDevice = require("./TTSDevice")(env)
  spawn = require('child_process').spawn
  fs = require('fs')
  
  class PicoTTSDevice extends TTSDevice
    
    constructor: (@config, lastState) ->
      @id = @config.id
      @name = @config.name
      
      @_options = {
        audioDecoder: require('wav').Reader
        audioFormat: 'wav'
        executable: @config.executable ? '/usr/bin/pico2wav'
        arguments: (file, text) => return [ '-l', @_options.language, '-w', file, text]
      }
      
      @actions = _.cloneDeep @actions
      @attributes =  _.cloneDeep @attributes
      
      super()

    getTTS: () =>
      env.logger.debug __("%s: Getting TTS Resource for text: %s, language: %s", @id, @_data.text.parsed, @_options.language)
      
      return new Promise( (resolve, reject) =>
        file = @_generateHashedFilename()
        
        fs.open(file, 'r', (error, fd) =>
          if error
            if error.code is "ENOENT"
              env.logger.debug("%s: Creating speech resource file '%s' using %s", @id, file, @_options.executable)
              
              env.logger.info("%s: Generating speech resource for '%s'", @id, @_data.text.parsed)
              
              #
              pico = spawn(@_options.executable, @_options.arguments(file, @_data.text.parsed))
              pico.stdout.on( 'data', (data) =>
                env.logger.debug __("%s output: %s", @_options.executable, data)
              )
              
              pico.stderr.on('data', (error) =>
                @base.rejectWithErrorString Promise.reject, error
              )
              
              pico.on('close', (code) =>
                if (code is 0)
                  env.logger.info __("%s: Speech resource for '%s' successfully generated.", @id, @_data.text.parsed)
                  
                  resolve file
                else
                  @base.rejectWithErrorString Promise.reject, error
              )
              #
              
            else
              # something else is wrong. file exists but cannot be read
              env.logger.warning __("%s: %s already exists, but cannot be accessed. Attempting to remove. Error: %s", @id, file, error.code)
              @_removeResource(file)
              
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
  
  return PicoTTSDevice