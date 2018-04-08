module.exports = (env) ->
  _ = env.require 'lodash'
  commons = require('pimatic-plugin-commons')(env)
  Promise = env.require 'bluebird'
  TTSDevice = require("./TTSDevice")(env)
  spawn = require('child_process').spawn
  fs = require('fs')
  wav = require('wav')
  
  class PicoTTSDevice extends TTSDevice
    
    constructor: (@config, lastState) ->
      @id = @config.id
      @name = @config.name
      
      @actions = _.cloneDeep @actions
      @attributes = _.cloneDeep @attributes
      
      super()
      
    _setup: ->
      @_setAudioDecoder(wav.Reader)
      @_audioFormat('wav')
      @_setExecutable(@config.executable ? '/usr/bin/pico2wav')
      @_setArguments((file, text) => return [ '-l', @_options.language, '-w', file, text])
    
    generateResource: (file, text) =>
      
      return new Promise( (resolve, reject) =>
        
        app = spawn(@_options.executable, @_options.arguments(file, text))
        app.stdout.on( 'data', (data) =>
          env.logger.debug __("%s output: %s", @_options.executable, data)
        
        )
        app.stderr.on('data', (error) =>
          @base.rejectWithErrorString Promise.reject, error
        
        )
        app.on('close', (code) =>
          
          if (code is 0)
            env.logger.info __("%s: Speech resource for '%s' successfully generated.", @id, text)
            resolve file
          
          else
            @base.rejectWithErrorString Promise.reject, error
        )
      ).catch( (error) => @base.rejectWithErrorString Promise.reject, error )
    
    _setExecutable: (value) ->
      if value is @_options.executable then return
      @_options.executable = value
      @emit 'executable', value
    
    _setArguments: (callback) ->
      @_options.arguments = callback
      
    destroy: () ->
      super()
  
  return PicoTTSDevice