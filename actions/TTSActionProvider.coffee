module.exports = (env) ->
  _ = env.require 'lodash'
  Promise = env.require 'bluebird'
  M = env.matcher
  commons = require('pimatic-plugin-commons')(env)

  class TTSActionProvider extends env.actions.ActionProvider
    
    constructor: (@framework, @config) ->
    
    parseAction: (input, context) =>
      ttsInput = {
        text: {
          input: null
          static: false
          parsed: null
        }
        device: null
        resource: null
      }
      
      SpeechDevices = _(@framework.deviceManager.devices).values().filter(
        (device) => device.hasAction("toSpeech")
      ).value()
      
      setDevice = (m, d) => ttsInput.device = d
      setText = (m, input) => 
        ttsInput.text.input = input
        ttsInput.text.static = !@framework.variableManager.extractVariables(input).length > 0
        
      m = M(input, context)
        .match(["speak ", "Speak ", "say ", "Say "])
        .matchStringWithVars(setText)
        .match(" using ")
        .matchDevice(SpeechDevices, setDevice)
        
      if m.hadMatch()
        match = m.getFullMatch()
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new TTSActionHandler(@framework, @config, ttsInput)
        }
      else
        return null
  
  class TTSActionHandler extends env.actions.ActionHandler
  
    constructor: (@framework, @config, @ttsActionData) ->
      @base = commons.base @, 'Pimatic-TTS-TTSActionProvider'
      super()
      
    setup: () ->
      @dependOnDevice(@ttsActionData.device)
      super()
    
    executeAction: (simulate) =>
      return new Promise( (resolve, reject) =>
        return @framework.variableManager.evaluateStringExpression(@ttsActionData.text.input).then( (text) =>
          @ttsActionData.text.parsed = text
          
          env.logger.debug __("TTSActionHandler - Device: '%s', Text: '%s'", @ttsActionData.device.id, @ttsActionData.text.parsed)
          
          if simulate
            return __("would convert Text to Speech: \"%s\"", @ttsActionData.text.parsed)
          
          else
            
            return @ttsActionData.device.toSpeech(@ttsActionData).then( (result) =>
              env.logger.debug result
              resolve result
              
            ).catch( (error) =>
              @base.rejectWithErrorString Promise.reject, error
            )
            
        ).catch( (error) => @base.rejectWithErrorString Promise.reject, error )
      ).catch( (error) => @base.rejectWithErrorString Promise.reject, error )
    
    destroy: () ->
      super()
  
  return TTSActionProvider
  
  