module.exports = (env) ->
  
  _ = env.require 'lodash'
  commons = require('pimatic-plugin-commons')(env)
  t = env.require('decl-api').types
  Promise = env.require 'bluebird'
  TTSDevice = require("./TTSDevice")(env)
  GoogleAPI = require('google-tts-api')
  Request = require('request')
  fs = require('fs')
  
  #
  # define the audio decoder module source here if needed
  #
  decoder = require('<decoder module')
    
  class GoogleTTSDevice extends TTSDevice
    
    constructor: (@config, lastState) ->
      @id = @config.id
      @name = @config.name
      
      @actions = _.cloneDeep @actions
      @attributes = _.cloneDeep @attributes
      
      # Define Getter methods specific to this subclass
      @actions.getAttribute = {
        description: "Define additional getter methods here"
        returns:
          speed:
            type: t.number}
      
      # Define Attributes specific to this subclass
      @attributes.attrib = {
        description: "Define additional attributes here"
        type: t.number
        acronym: 'Attribute:'
        discrete: true}
      
      #
      # Define additional options here or overload properties from the parent class
      # These can be also be loaded from the device config, if you define these as a setting there
      #
      # REQUIRED: .AudioDecoder must point to the ClassName of the decoder you use
      # REQUIRED: .AudioFormat must contain a file extension such as mp3,wav, etc. Depends on the TTS and decoder you use
      
      @_options = {
        device_option: @config.device_option ? '<default>' 
        audioDecoder: decoder.Decoder 
        audioFormat: 'mp3'
      }
      
      super()
    
    # Implement Getter methods for defined Getters
    getSpeed: -> Promise.resolve(@_options.speed)
    
    #
    # REQUIRED: generateResource: (file) -> Promise(resolve file, reject error)
    #
    # This method is the specific TTS resource generator, which should output an audio resource on disk with filename <file>
    # 
    # The subClass must implement this method accepting a filename (string) as input
    # It must return a Promise 
    #   resolving with the same file (string) after successfully generating the TTS audio resource
    #   reject with an error on failure
    #
    # This Subclass inherits @_data and @_options objects which can be accessed in your method to generate the resource
    #
    # @_data = {
    #    text: {
    #      input: <string>    -> Text string with unparsed variables
    #      static: <boolean>  -> Indicates whether the string contains variables
    #      parsed: <string>   -> Text string with resolved variables, to be used for generating TTS
    #    }
    # }
    #
    # @_options.language = <string>   -> BCP-47 language identifier
    # @_options.volume = <number>     -> Integer between 1 and 100
    #
    generateResource: (file) =>
      
      return new Promise( (resolve, reject) =>
        
        # Example implementation
        
        ttsAPI(@_data.text.parsed, @_options.language).then( (resource) =>
        
        readStream = Request.get(resource)
          .on('error', (error) =>
            msg = __("%s: Failure reading audio resource '%s'. Error: %s", @id, resource, error)
            env.logger.debug msg
            @base.rejectWithErrorString Promise.reject, msg
          )
            
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
            
          readStream.pipe(fsWrite)
              
        ).catch( (error) => @base.rejectWithErrorString Promise.reject, error )
      ).catch( (error) => @base.rejectWithErrorString Promise.reject, error )
    
    destroy: () ->
      super()
  
  return GoogleTTSDevice