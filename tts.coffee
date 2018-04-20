TTSProviders =
  'Google':
    device: 'GoogleTTSDevice'
    deviceDef: 'google-device-config-schema'
    langResource: 'google-tts-api-lang.json'
  'Pico':
    device: 'PicoTTSDevice'
    deviceDef: 'pico-device-config-schema'
    langResource: 'pico-tts-api-lang.json'
    
OutputProviders =
  'DLNA':
    device: 'DLNAPlayerDevice'
    deviceDef: 'dlnaplayer-device-config-schema'

module.exports = (env) ->

  _ = env.require 'lodash'
  Promise = env.require 'bluebird'
  commons = require('pimatic-plugin-commons')(env)
  DLNA = require 'dlnacasts'
  MediaRenderer = require 'upnp-mediarenderer-client'

  class TextToSpeechPlugin extends env.plugins.Plugin
    
    init: (app, @framework, @config) =>
      @debug = @config.debug || false
      @base = commons.base @, 'Plugin'
      
      for own obj of TTSProviders
        do (obj) =>
          TTSProvider = TTSProviders[obj]
          
          @base.debug "Registering device class #{TTSProvider.device}"
          deviceConfig = require("./devices/" + TTSProvider.deviceDef)
          
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
      
      for own obj of OutputProviders
        do (obj) =>
          OutputProvider = OutputProviders[obj]
          
          @base.debug "Registering device class #{OutputProvider.device}"
          deviceConfig = require("./devices/" + OutputProvider.deviceDef)
          deviceClass = require('./devices/' + OutputProvider.device)(env)
          
          params = {
            configDef: deviceConfig[OutputProvider.device], 
            createCallback: (config, lastState) => return new deviceClass(config, lastState, @)
          }
          @framework.deviceManager.registerDeviceClass(OutputProvider.device, params)
      
      @base.debug "Registering action provider"
      actionProviderClass = require('./actions/TTSActionProvider')(env)
      @framework.ruleManager.addActionProvider(new actionProviderClass(@framework, @config))

      @_discoveryDuration = ( @config.discoveryTimeout ? 10 )*1000
      @_discoveryInterval = ( @config.discoveryInterval ? 30 )*1000
      @_discoveryInterval = @_discoveryDuration*2 unless @_discoveryInterval > @_discoveryDuration*2
      
      @_discoveryStartTimer = null
      @_discoveryStopTimer = null
      
      @_dlnaDeviceList = []
      
      @dlnaDiscovery()
    
    dlnaDiscovery: () =>
      
      dlnaBrowser = null
      discoveredDevices = null
      
      dlnaDeviceFound = (config) =>
        @base.debug __("DLNA device discovered: %s", config.name)
        
        config.id = @_createDeviceId(config.name)
        config.client = new MediaRenderer(config.xml)
        
        if !@_isNewDevice(config.id)
          @emit('dlnaDeviceDiscovered', config)
        
        else
          @_createDeviceFromDlnaConfig(config).catch( (error) => 
            @base.error __("Error creating device '%s': %s", config.id, error)
          )
      
      discoveryStop = =>
        @base.debug __("DLNA device discovery stopped")
        
        dlnaBrowser.removeListener('update', dlnaDeviceFound)
        dlnaBrowser = null
        @emit('dlnaDiscoveryEnd', true)
        
      discoveryStart = =>
        @base.debug "DLNA device discovery started"
        
        discoveredDevices = []
        dlnaBrowser = DLNA()
        dlnaBrowser.on('update', dlnaDeviceFound)
        
        @_discoveryStopTimer = setTimeout(discoveryStop, @_discoveryDuration)
        @_discoveryStartTimer = setTimeout(discoveryStart, @_discoveryInterval)
      
      discoveryStart()
      
    _createDeviceFromDlnaConfig: (config) =>
      
      return new Promise( (resolve, reject) =>
        @base.debug __("Creating Pimatic DLNA device: %s", config.name)
        
        device = @framework.deviceManager.addDeviceByConfig( @_createDeviceConfig(config) )
        resolve device.updateDevice(true, config)
        
      ).catch( (error) => reject error)
    
    _isNewDevice: (id) -> return !@framework.deviceManager.isDeviceInConfig(id)
    _createDeviceId: (id) -> return 'dlna-' + id.replace(/(^[\W]|[\W]$)/g, '').replace(/[\W]+/g, '-').toLowerCase()
    _createDeviceConfig: (dlnaConfig) -> return { id: dlnaConfig.id, name: dlnaConfig.name, class: OutputProviders.DLNA.device }
    
    destroy: () ->
      clearTimeout @_discoveryStartTimer
      clearTimeout @_discoveryStopTimer

      @_discoveryStartTimer = undefined
      @_discoveryStopTimer = undefined
      
      @_dlnaBrowser.removeListener('update', dlnaDeviceFound)
      @removeAllListeners('dlnaDeviceDiscovered')
      @removeAllListeners('dlnaDiscoveryEnd')
      
  TTSPlugin = new TextToSpeechPlugin
  return TTSPlugin