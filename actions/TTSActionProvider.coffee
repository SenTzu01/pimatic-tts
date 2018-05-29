module.exports = (env) ->
  _ = env.require 'lodash'
  Promise = env.require 'bluebird'
  M = env.matcher
  commons = require('pimatic-plugin-commons')(env)
  t = env.require('decl-api').types

  class TTSActionProvider extends env.actions.ActionProvider
    
    constructor: (@framework, @config) ->
      @base = commons.base @, 'tts-ActionProvider'
      @debug = @config.debug

      super()
      
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
          volume: {
            input: null,
            parsed: null
          },
          repeat: {
            number: {
              input: null,
              parsed: null
            },
            interval: {
              input: null,
              parsed: null
            }
          }
        },
        output: {
          device: null,
          cache: null,
          resource: null,
          volume: {
            input: null,
            parsed: null
          }
          format: {
            type: 'mp3'
            duration: null
          }
        }
      }
      
      devicesWithAction = (f) =>
        _(@framework.deviceManager.devices).values().filter( (device) => 
          device.hasAction(f)
        ).value()
      
      setText = (m, t) =>
        ttsSettings.text.input = t
        ttsSettings.text.static = !@framework.variableManager.extractVariables(t).length > 0
      
      setSpeechVolume = (m) =>
        m.match([" with volume "])
          .matchNumericExpression( (m, v) =>
            ttsSettings.speech.volume.input = v
            ttsSettings.output.volume.input = v
          )
      
      setSpeechRepeatNumber = (m) =>
        m.match([" repeating "])
          .matchNumericExpression( (m, r) =>
            ttsSettings.speech.repeat.number.input = r
          )
          .match([" times"]
        )
      
      setSpeechRepeatInterval = (m) =>
        m.match([" every "])
          .matchNumericExpression( (m, w) =>
            ttsSettings.speech.repeat.interval.input = w
          )
          .match([" s", " seconds"]
        )
      
      setOutputDevice = (m) =>
        m.match([" via "])
          .matchDevice(devicesWithAction("playAudio"), (m, d) =>
            ttsSettings.output.device = d
          )
        
      setDevice = (m, d) =>
        device = d
        ttsSettings.speech.volume.input = [d.config.volume]
        ttsSettings.output.volume.input = [d.config.volume]
        ttsSettings.speech.repeat.number.input = [d.config.repeat]
        ttsSettings.speech.repeat.interval.input = [d.config.interval]
      
      m = M(input, context)
        .match(["speak ", "Speak ", "say ", "Say "])
        .matchStringWithVars(setText)
        .match([" using "])
        .matchDevice(devicesWithAction("textToSpeech"), setDevice)
        .optional(setOutputDevice)
        .optional(setSpeechVolume)
        .optional(setSpeechRepeatNumber)
        .optional(setSpeechRepeatInterval)

      if m.hadMatch()
        match = m.getFullMatch()
        
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new TTSActionHandler(@framework, device, ttsSettings)
        }
      else
        return null
  
  class TTSActionHandler extends env.actions.ActionHandler
  
    constructor: (@framework, @_device, @_ttsSettings) ->
      @base = commons.base @, 'tts-ActionHandler'
      
      super()
      
    setup: () ->
      @dependOnDevice(@_device)
      @dependOnDevice(@_ttsSettings.output.device) if @_ttsSettings?.output?.device?
      
      super()
    
    executeAction: (simulate) =>
      Promise.join(
        @framework.variableManager.evaluateStringExpression(@_ttsSettings.text.input),
        @framework.variableManager.evaluateNumericExpression(@_ttsSettings.speech.volume.input)
        @framework.variableManager.evaluateNumericExpression(@_ttsSettings.output.volume.input),
        @framework.variableManager.evaluateNumericExpression(@_ttsSettings.speech.repeat.number.input),
        @framework.variableManager.evaluateNumericExpression(@_ttsSettings.speech.repeat.interval.input),
        (text, speechVolume, outputVolume, repeat, interval) =>
          cfg = @_ttsSettings
          cfg.text.parsed = text
          cfg.speech.volume.parsed = speechVolume
          cfg.output.volume.parsed = outputVolume
          cfg.speech.repeat.number.parsed = repeat
          cfg.speech.repeat.interval.parsed = interval
          cfg.speech.repeat.interval.parsed = 0 if cfg.speech.repeat.number.parsed < 2
          
          if simulate
            return Promise.resolve __("would convert Text to Speech: \"%s\"", cfg.text.parsed)
          
          else
            @base.debug __("TTSActionHandler - Device: '%s', Text: '%s'", @_device.id, cfg.text.parsed)
            
            @_device.textToSpeech(cfg)
            .then( (result) =>
              return Promise.resolve result
            )
            .catch( (error) =>
              return Promise.reject error
            )
      )
      .catch( (error) =>
        return Promise.resolve true
      )
    
    destroy: () ->
      super()
  
  return TTSActionProvider
  
  