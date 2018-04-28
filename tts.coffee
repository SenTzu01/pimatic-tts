module.exports = (env) ->

  _ = env.require 'lodash'
  Promise = env.require 'bluebird'
  commons = require('pimatic-plugin-commons')(env)
  DlnaDiscovery = require('./lib/DlnaDiscovery')(env)
  os = require('os')
  
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
      
  class TextToSpeechPlugin extends env.plugins.Plugin
    
    init: (app, @framework, @config) =>
      @debug = @config.debug || false
      @base = commons.base @, 'Plugin'
      
      @_dlnaBrowser = null
      @_inetAddresses = []
      
      @_configureMediaServerAddress()
      
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
            createCallback: (config, lastState) => return new deviceClass(config, lastState, @config)
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

      @_discoverNetworkPlayers() if @config.enableDiscovery
      
    
    
    _discoverNetworkPlayers: () =>
      discoveryInterval = ( @config.discoveryInterval ? 30 )*1000
      discoveryDuration = ( @config.discoveryTimeout ? 10 )*1000
      discoveryInterval = discoveryDuration*2 unless discoveryInterval > discoveryDuration*2
      
      @_dlnaBrowser = new DlnaDiscovery(discoveryInterval, discoveryDuration, false)
      @_dlnaBrowser.on('new', (config) =>
      
        @emit('dlnaDeviceDiscovered', config)
        @_createDeviceFromDlnaConfig(config) if @_isNewDevice(config.id)
      )
      @_dlnaBrowser.on('stop', =>
        @emit 'dlnaDiscoveryEnd', true
      )
      @_dlnaBrowser.start()
    
    
    
    _createDeviceFromDlnaConfig: (dlnaConfig) =>
      @base.debug __("Creating new network media player device: %s", dlnaConfig.name)
      
      device = @framework.deviceManager.addDeviceByConfig({
        id: dlnaConfig.id
        name: __("Media Server %s", dlnaConfig.name)
        class: OutputProviders.DLNA.device })
      
      if device?
        device.updateDevice(dlnaConfig, true)
      else 
        @base.error __("Error creating new network media player device '%s'", dlnaConfig.id)
    
    
    
    _isNewDevice: (id) -> 
      return !@framework.deviceManager.isDeviceInConfig(id)
    
    
    
    _configureMediaServerAddress: () ->
      @_inetAddresses = @_getConfiguredAddresses()
      
      pluginConfigSchema = @framework.pluginManager.getPluginConfigSchema("pimatic-tts")
      pluginConfigSchema.properties.address.enum = []
      
      @base.info "Configured external IP addresses:"
      @_inetAddresses.map( (address) =>
        pluginConfigSchema.properties.address.enum.push address.IPv4 if address.IPv4?
        pluginConfigSchema.properties.address.enum.push address.IPv6 if address.IPv6?
        @base.info __("IPv4: %s, IPv6: %s", address.IPv4, address.IPv6)
      )
      
      if @config.address is ""
        @config.address = @_getPimaticAddress() ? @_inetAddresses[0].IPv4 ? @_inetAddresses[0].IPv6 ? ""
        @framework.pluginManager.updatePluginConfig(@config.plugin, @config)
      
      @base.info __("Address: %s has been configured", @config.address)
    
    
    
    _getConfiguredAddresses: () ->
      netInterfaces = []
      ifaces = os.networkInterfaces()
      for iface, ipConfig of ifaces
        addresses = null
        ipConfig.map( (ip) =>
          if !ip.internal
            addresses ?= { IPv4: "", IPv6: "" }
            addresses[ip.family] = ip.address if ip.family is 'IPv4' or 'IPv6'
        )
        netInterfaces.push addresses if addresses?
      return netInterfaces
    
    
    
    _getPimaticAddress: () ->
      appSettings = @framework.config?.settings
      ip = settings?.httpServer?.hostname ? settings?.httpsServer?.hostname ? null
      env.logger.debug __("User defined IP address in Pimatic settings: %s", ip)
      
      return ip
      
    destroy: () ->
      #@_dlnaBrowser.stop() if @_dlnaBrowser?
      
  TTSPlugin = new TextToSpeechPlugin
  return TTSPlugin