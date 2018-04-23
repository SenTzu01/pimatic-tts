module.exports = (env) ->
  _ = env.require 'lodash'
  Promise = env.require 'bluebird'
  M = env.matcher
  commons = require('pimatic-plugin-commons')(env)
  t = env.require('decl-api').types

  class TTSActionProvider extends env.actions.ActionProvider
    
    constructor: (@framework, @config) ->
      @base = commons.base @, 'Pimatic-TTS-TTSActionProvider'
      
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
        },
        output: {
          device: null
          volume: null
        }
      }
      
      devicesWithFunction = (f) =>
        _(@framework.deviceManager.devices).values().filter( (device) => 
          device.hasAction(f)
        ).value()
      
      setText = (m, t) =>
        ttsSettings.text.input = t
        ttsSettings.text.static = !@framework.variableManager.extractVariables(t).length > 0
      
      setSpeechVolume = (m) =>
        m.match([" with volume "]).matchNumericExpression( (m, v) =>
          ttsSettings.speech.volume = v
          ttsSettings.output.volume = v
        )
      
      setSpeechRepeatNumber = (m) =>
        m.match([" repeating "]).matchNumericExpression( (m, r) =>
          ttsSettings.speech.repeat.number = r
        ).match([" times"])
      
      setSpeechRepeatInterval = (m) =>
        m.match([" every "]).matchNumericExpression( (m, w) =>
          ttsSettings.speech.repeat.interval = w
        ).match([" s", " seconds"])
      
      setOutputDevice = (m) =>
        m.match([" via "]).matchDevice(devicesWithFunction("playAudio"), (m, d) =>
          ttsSettings.output.device = d
        )
        
      setDevice = (m, d) =>
        device = d
        ttsSettings.speech.volume = [d.config.volume]
        ttsSettings.output.volume = [d.config.volume]
        ttsSettings.speech.repeat.number = [d.config.repeat]
        ttsSettings.speech.repeat.interval = [d.config.interval]
      
      m = M(input, context)
        .match(["speak ", "Speak ", "say ", "Say "])
        .matchStringWithVars(setText)
        .match(" using ")
        .matchDevice(devicesWithFunction("textToSpeech"), setDevice)
        .optional(setOutputDevice)
        .optional(setSpeechVolume)
        .optional(setSpeechRepeatNumber)
        .optional(setSpeechRepeatInterval)

      if m.hadMatch()
        match = m.getFullMatch()
        env.logger.debug ttsSettings
        
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new TTSActionHandler(@framework, @config, device, ttsSettings)
        }
      else
        return null
  
  class TTSActionHandler extends env.actions.ActionHandler
  
    constructor: (@framework, @config, @_device, @_ttsSettings) ->
      @base = commons.base @, 'Pimatic-TTS-TTSActionHandler'
      super()
      
    setup: () ->
      @dependOnDevice(@_device)
      @dependOnDevice(@ttsSettings.output.device) if @ttsSettings?.output?.device?
      super()
    
    executeAction: (simulate) =>
      return new Promise( (resolve, reject) =>
        return Promise.join(
          @framework.variableManager.evaluateStringExpression(@_ttsSettings.text.input),
          @framework.variableManager.evaluateNumericExpression(@_ttsSettings.speech.volume),
          @framework.variableManager.evaluateNumericExpression(@_ttsSettings.output.volume),
          @framework.variableManager.evaluateNumericExpression(@_ttsSettings.speech.repeat.number),
          @framework.variableManager.evaluateNumericExpression(@_ttsSettings.speech.repeat.interval),
          (text, speechVolume, outputVolume, repeat, interval) =>
            @_ttsSettings.text.parsed = text
            @_ttsSettings.speech.volume = speechVolume
            @_ttsSettings.output.volume = outputVolume
            @_ttsSettings.speech.repeat.number = repeat
            @_ttsSettings.speech.repeat.interval = interval
            @_ttsSettings.speech.repeat.interval = 0 if @_ttsSettings.speech.repeat.number < 2
            env.logger.debug @_ttsSettings
            
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
  
  