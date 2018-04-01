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

    generateResource: (file) =>
      
      return new Promise( (resolve, reject) =>
        
        app = spawn(@_options.executable, @_options.arguments(file, @_data.text.parsed))
        app.stdout.on( 'data', (data) =>
          env.logger.debug __("%s output: %s", @_options.executable, data)
        
        )
        app.stderr.on('data', (error) =>
          @base.rejectWithErrorString Promise.reject, error
        
        )
        app.on('close', (code) =>
          
          if (code is 0)
            env.logger.info __("%s: Speech resource for '%s' successfully generated.", @id, @_data.text.parsed)
            resolve file
          
          else
            @base.rejectWithErrorString Promise.reject, error
        )
      ).catch( (error) => @base.rejectWithErrorString Promise.reject, error )
      
    destroy: () ->
      super()
  
  return PicoTTSDevice