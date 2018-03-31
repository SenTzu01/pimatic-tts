TTSProviders =
  'Google':
    device: 'GoogleTTSDevice'
    deviceDef: 'google-device-config-schema'
    langResource: 'google-tts-api-lang.json'
  'Pico':
    device: 'PicoTTSDevice'
    deviceDef: 'pico-device-config-schema'
    langResource: 'pico-tts-api-lang.json'
    
module.exports = (env) ->

  Promise = env.require 'bluebird'
  commons = require('pimatic-plugin-commons')(env)
  M = env.matcher
  
  class TextToSpeechPlugin extends env.plugins.Plugin
    
    init: (app, @framework, @config) =>
      @debug = @config.debug || false
      @base = commons.base @, 'Plugin'
      
      for own obj of TTSProviders
        do (obj) =>
          TTSProvider = TTSProviders[obj]
          
          @base.debug "Registering device class #{TTSProvider.device}"
          deviceConfig = require("./" + TTSProvider.deviceDef)
          
          if TTSProvider.langResource?
            languages = require('./resources/'+ TTSProvider.langResource)
            
            for own obj of languages
              do (obj) =>
                
                language = languages[obj]
                if 0 > deviceConfig[TTSProvider.device].properties.language?.enum.indexOf(language.code)
                  deviceConfig[TTSProvider.device].properties.language.enum.push language.code
          
          deviceClass = require('./devices/' + TTSProvider.device)(env)
          params = {
            configDef: deviceConfig[TTSProvider.device], 
            createCallback: (config, lastState) => return new deviceClass(config, lastState)
          }
          
          @framework.deviceManager.registerDeviceClass(TTSProvider.device, params)
      
      @base.debug "Registering action provider"
      actionProviderClass = require('./actions/TTSActionProvider')(env)
      @framework.ruleManager.addActionProvider(new actionProviderClass(@framework, @config))
         
  Plugin = new TextToSpeechPlugin
  return Plugin