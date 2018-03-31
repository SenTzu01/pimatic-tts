module.exports = (env) ->

  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  TTSActionProvider = require('./TTSActionProvider')(env)
  

      
  class GoogleTTSActionProvider extends TTSActionProvider
    constructor: (@framework, @config) ->
      @_setProvider({
        deviceClass: "GoogleTTSDevice", 
        actionHandler: GoogleTTSActionHandler
      })
      super()
      
    parseAction: (input, context) =>
      return @_parse(input, context)
  
  return GoogleTTSActionProvider