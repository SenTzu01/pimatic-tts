module.exports = (env) ->
  _ = env.require 'lodash'
  Promise = env.require 'bluebird'
  M = env.matcher
  commons = require('pimatic-plugin-commons')(env)
  t = env.require('decl-api').types

  class TTSActionProvider extends env.actions.ActionProvider
    
    constructor: (@framework, @config) ->
    
    parseAction: (input, context) =>
      device = null
      ttsSettings = {
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
        device.hasAction("textToSpeech")
      ).value()
      
      
      setText = (m, input) => 
        ttsSettings.text.input = input
        ttsSettings.text.static = !@framework.variableManager.extractVariables(input).length > 0
      
      setSpeechVolume = (m, v) =>
        m.match([" with volume "]).matchNumber( (m, v) =>
          ttsSettings.speech.volume = v
        )
      
      setSpeechRepeatNumber = (m, r) => 
        m.match([" repeating "]).matchNumber( (m, r) =>
          ttsSettings.speech.repeat.number = r
        ).match([" times"])
      
      setSpeechRepeatInterval = (m, w) => 
        m.match([" every "]).matchNumber( (m, w) =>
          ttsSettings.speech.repeat.interval = w
        ).match([" s", " seconds"])
      
      setDevice = (m, d) => 
        device = d
        ttsSettings.speech.volume = d.config?.volume
        ttsSettings.speech.repeat.number = d.config?.repeat
        ttsSettings.speech.repeat.interval = d.config?.interval

      m = M(input, context)
        .match(["speak ", "Speak ", "say ", "Say "])
        .matchStringWithVars(setText)
        .match(" using ")
        .matchDevice(SpeechDevices, setDevice)
        .optional(setSpeechVolume)
        .optional(setSpeechRepeatNumber)
        .optional(setSpeechRepeatInterval)

      if m.hadMatch()
        ttsSettings.speech.repeat.interval = 0 if ttsSettings.speech.repeat.number < 2
        match = m.getFullMatch()
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new TTSActionHandler(@framework, @config, device, ttsSettings)
        }
      else
        return null
  
  class TTSActionHandler extends env.actions.ActionHandler
  
    constructor: (@framework, @config, @_device, @_ttsSettings) ->
      @base = commons.base @, 'Pimatic-TTS-TTSActionProvider'
      super()
      
    setup: () ->
      @dependOnDevice(@_device)
      super()
    
    executeAction: (simulate) =>
      return new Promise( (resolve, reject) =>
        return @framework.variableManager.evaluateStringExpression(@_ttsSettings.text.input).then( (text) =>
          @_ttsSettings.text.parsed = text
          
          env.logger.debug __("TTSActionHandler - Device: '%s', Text: '%s'", @_device.id, @_ttsSettings.text.parsed)
          
          if simulate
            return __("would convert Text to Speech: \"%s\"", @_ttsSettings.text.parsed)
          
          else
            
            return @_device.textToSpeech(@_ttsSettings).then( (result) =>
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
  
  