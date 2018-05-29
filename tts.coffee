module.exports = (env) ->

  _ = env.require 'lodash'
  Promise = env.require 'bluebird'
  commons = require('pimatic-plugin-commons')(env)
  os = require('os')
  
  TTSProviders =
    Google:
      device: 'GoogleTTSDevice'
      deviceDef: 'tts-device-config-schemas'
      langResource: 'google-tts-api-lang.json'
    Pico:
      device: 'PicoTTSDevice'
      deviceDef: 'tts-device-config-schemas'
      langResource: 'pico-tts-api-lang.json'
      
  OutputProviders =
    local:
      type: 'LocalAudio'
      device: 'LocalAudioMediaPlayerDevice'
      deviceDef: 'mediaplayer-device-config-schemas'
    generic:
      type: 'UPnP'
      device: 'UPnPMediaPlayerDevice'
      deviceDef: 'mediaplayer-device-config-schemas'
    chromecast:
      type: 'Chromecast'
      device: 'ChromecastMediaPlayerDevice'
      deviceDef: 'mediaplayer-device-config-schemas'
  
  class TextToSpeechPlugin extends env.plugins.Plugin
    
    init: (app, @framework, @config) =>
      @debug = @config.debug || false
      @base = commons.base @, 'Plugin'
      
      @_inetAddresses = []
      
      @_configureMediaServerAddress()
      
      listeners = []
      discoveryInterval = @_toMilliSeconds( @config.discoveryInterval ? 30 )
      discoveryDuration = @_toMilliSeconds( @config.discoveryTimeout ? 10 )
      discoveryInterval = discoveryDuration*2 unless discoveryInterval > discoveryDuration*2
      
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
            createCallback: (config, lastState) => return new deviceClass(config, lastState, @config)
          }
          
          @framework.deviceManager.registerDeviceClass(TTSProvider.device, params)
      
      for own obj of OutputProviders
        do (obj) =>
          OutputProvider = OutputProviders[obj]
          listener = null
          
          unless obj is 'local'
            @base.debug "Starting discovery of #{OutputProvider.type} media player devices"
            Discovery = require("./lib/" + OutputProvider.type + "Discovery")(env)
            listener = new Discovery(discoveryInterval, discoveryDuration, @config.address, null, @debug) #@debug
            listeners.push listener
            
            listener.on('deviceDiscovered', (cfg) =>
              if @config.enableDiscovery and @_isNewDevice(cfg.id)
                newDevice = @_createPimaticDevice(cfg)
                newDevice.updateDevice(cfg)
            )
            listener.start()
          
          className = "#{OutputProvider.device}"
          @base.debug __("Registering device class: %s", className)
          
          deviceConfig = require("./" + OutputProvider.deviceDef)
          deviceClass = require('./devices/' + className)(env)
          
          params = {
            configDef: deviceConfig[className], 
            createCallback: (config, lastState) => return new deviceClass(config, lastState, listener, @debug) #@debug
          }
          @framework.deviceManager.registerDeviceClass(className, params)
          
          
      
      @base.debug "Registering action provider"
      actionProviderClass = require('./actions/TTSActionProvider')(env)
      @framework.ruleManager.addActionProvider(new actionProviderClass(@framework, @config))
    
    _createPimaticDevice: (cfg) =>
      return if !cfg? or !cfg.id? or !cfg.name?
      @base.debug __("Creating new network media player device: %s with IP: %s", cfg.name, cfg.address)
      
      return @framework.deviceManager.addDeviceByConfig({
        id: cfg.id,
        name: cfg.name
        class: OutputProviders[cfg.type].device
      })
    
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
    
    _toMilliSeconds: (s) -> return s * 1000
    
    _getPimaticAddress: () ->
      appSettings = @framework.config?.settings
      ip = settings?.httpServer?.hostname ? settings?.httpsServer?.hostname ? null
      env.logger.debug __("User defined IP address in Pimatic settings: %s", ip)
      
      return ip
      
    destroy: () ->
      super()
      
  TTSPlugin = new TextToSpeechPlugin
  return TTSPlugin