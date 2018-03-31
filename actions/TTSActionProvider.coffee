module.exports = (env) ->
  _ = env.require 'lodash'
  Promise = env.require 'bluebird'
  M = env.matcher

  class TTSActionProvider extends env.actions.ActionProvider
    
    constructor: (@framework, @config) ->
    
    parseAction: (input, context) =>
      ttsInput = {
        text: null,
        device: null,
        language: null,
        speed: null,
        volume: null,
        iterations: null,
        interval: null
      }
      
      SpeechDevices = _(@framework.deviceManager.devices).values().filter(
        (device) => device.hasAction("convertToSpeech")
      ).value()
      
      setDevice = (m, d) => ttsInput.device = d
      setText = (m, input) => ttsInput.text = input
      setLanguage = (m, input) => ttsInput.language = input
      setSpeed = (m, input) => ttsInput.speed = input
      setVolume = (m, input) => ttsInput.volume = input
      setIterations = (m, input) => ttsInput.iterations = input
      setDelay = (m, input) => ttsInput.interval = input
      
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
      super()
      
    setup: () ->
      @dependOnDevice(@ttsActionData.device)
      super()
    
    executeAction: (simulate) =>
      console.log @framework.variableManager.extractVariables(@ttsActionData.text)
      @framework.variableManager.evaluateStringExpression(@ttsActionData.text).then( (text) =>
        env.logger.debug __("TTSActionHandler - Text: %s, Device: %s", text, @ttsActionData.device.id)
        if simulate
          return __("would convert Text to Speech: \"%s\"", text)
        
        else
          return new Promise( (resolve, reject) =>
            @ttsActionData.device.convertToSpeech(text).then( (result) =>
              env.logger.debug result
              resolve result
            )
          ).catch( (error) =>
            env.logger.error error
            @base.rejectWithErrorString Promise.reject, error
          )
      )
    
    destroy: () ->
      super()
  
  return TTSActionProvider
  
  