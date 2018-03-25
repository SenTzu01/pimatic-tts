module.exports = (env) ->
  _ = env.require 'lodash'
  M = env.matcher

  class TTSActionProvider extends env.actions.ActionProvider
    _ttsProvider: null
    
    constructor: () ->
      throw new Error "You must set property\"ttsProvider\" !" if !@_ttsProvider?
    
    _setProvider: (provider) ->
      @_ttsProvider = provider

      
    _parse: (input, context) =>
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
        (device) => device.config.class is @_ttsProvider.deviceClass
      ).value()
      
      setDevice = (m, d) => ttsInput.device = d
      setText = (m, input) => ttsInput.text = input
      setLanguage = (m, input) => ttsInput.language = input
      setSpeed = (m, input) => ttsInput.speed = input
      setVolume = (m, input) => ttsInput.volume = input
      setIterations = (m, input) => ttsInput.iterations = input
      setDelay = (m, input) => ttsInput.interval = input
      
      m = M(input, context)
        .match("Say ")
        .matchStringWithVars(setText)
        .match(" using ")
        .matchDevice(SpeechDevices, setDevice)
        
      if m.hadMatch()
        match = m.getFullMatch()
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new @_ttsProvider.actionHandler(@framework, @config, ttsInput)
        }
      else
        return null
  
  return TTSActionProvider