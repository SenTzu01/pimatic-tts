module.exports = (env) ->
  _ = env.require 'lodash'
  Promise = env.require 'bluebird'
  M = env.matcher
  commons = require('pimatic-plugin-commons')(env)
  t = env.require('decl-api').types

  class TTSActionProvider extends env.actions.ActionProvider
    
    constructor: (@framework, @config) ->
    
    parseAction: (input, context) =>
      ttsConversion = {
        device: null,
        text: {
          input: '',
          static: false,
          parsed: ''
        },
        speech: {
          resource: '',
          volume: null,
          repeat: {
            number: null,
            interval: null
          }
        }
      }
      
      SpeechDevices = _(@framework.deviceManager.devices).values().filter( (device) => 
        device.hasAction("toSpeech")
      ).value()
      
      
      setText = (m, input) => 
        ttsConversion.text.input = input
        ttsConversion.text.static = !@framework.variableManager.extractVariables(input).length > 0
      
      setSpeechVolume = (m, v) =>
        m.match([" with volume "]).matchNumber( (m, v) =>
          ttsConversion.speech.volume = v
        )
      
      setSpeechRepeatNumber = (m, r) => 
        m.match([" repeating "]).matchNumber( (m, r) =>
          ttsConversion.speech.repeat.number = r
        ).match([" times"])
      
      setSpeechRepeatInterval = (m, w) => 
        m.match([" every "]).matchNumber( (m, w) =>
          ttsConversion.speech.repeat.interval = w
        ).match([" s", " seconds"])
      
      setDevice = (m, d) => 
        ttsConversion.device = d
        ttsConversion.speech.volume = d.config?.volume?
        ttsConversion.speech.repeat.number = d.config?.repeat
        ttsConversion.speech.repeat.interval = d.config?.interval

      m = M(input, context)
        .match(["speak ", "Speak ", "say ", "Say "])
        .matchStringWithVars(setText)
        .match(" using ")
        .matchDevice(SpeechDevices, setDevice)
        .optional(setSpeechVolume)
        .optional(setSpeechRepeatNumber)
        .optional(setSpeechRepeatInterval)

      if m.hadMatch()
        ttsConversion.speech.repeat.interval = 0 if ttsConversion.speech.repeat.number < 2
        match = m.getFullMatch()
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new TTSActionHandler(@framework, @config, ttsConversion)
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
  
  