module.exports = (env) ->

  Promise = env.require 'bluebird'
  commons = require('pimatic-plugin-commons')(env)
  TTSDevice = require("./TTSDevice")(env)
  ExampleAPI = require("example-api")
  
  class TemplateTTSDevice extends TTSDevice
    
    constructor: (@config, lastState) ->
      # Set additional variables used by this specific implementation of a TTSDevice
      # Make sure to also define these in the device config file
      @_language = @config.language ? null
      @_speed = @config.speed ? null
      @_volume = @config.volume ? null
      
      # The constructor must call its parent passing the @config and lastState variables
      super(@config, lastState)
    
    #
    # You must implement the createSpeechResource method
    # The method must return a Promise which resolves to a resource identifier (e.g. a path or URL) which can be used by the audio player used for TTS output
    #
    createSpeechResource: (text, language, speed, ...) =>
      #
      # Set config defaults for parameters not passed as a function parameter
      #
      language ?= @_language
      speed ?= @_speed
      
      @_setLatestText(text)
      
      return new Promise( (resolve, reject) =>
        return commons.base.rejectWithErrorString Promise.reject, __("string provided is null or undefined") if !text?
        
        # IMPLEMENT TEXT-TO-SPEECH LOGIC HERE
        ExampleAPI(text, language).then( (resource) =>
          resolve resource
        ).catch( (error) =>
          commons.base.rejectWithErrorString Promise.reject, __("Error obtaining resource from Example: %s", error)
        )
      )
    
    #
    # You must implement the outputSpeech method
    # The method must return a Promise which resolves or rejects with a success or an error message respectively
    #
    outputSpeech:(volume, ...) =>
      #
      # Set config defaults for parameters not passed as a function parameter
      #
      volume ?= @_volume
      
      return new Promise( (resolve, reject) =>
        
        # IMPLEMENT AUDIO OUTPUT LOGIC HERE
        resolve __("Stub: Should be outputting %s with volume %s", @_latestResource, volume)
      
      ).catch( (error) =>
      
        # IMPLEMENT ERROR HANDLING FOR AUDIO OUTPUT LOGIC HERE
        commons.base.rejectWithErrorString Promise.reject, __("Audio output error: %s", error)
      )
    
    # you must implement the destroy method calling its parent
    destroy: () ->
      super()
  
  return TemplateTTSDevice