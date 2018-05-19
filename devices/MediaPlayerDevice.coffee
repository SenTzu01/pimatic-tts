module.exports = (env) ->
  
  _ = env.require 'lodash'
  commons = require('pimatic-plugin-commons')(env)
  Promise = env.require 'bluebird'
  t = env.require('decl-api').types
  
  class MediaPlayerDevice extends env.devices.PresenceSensor
    
    constructor: (lastState) ->
      @_detected = false
      @_pauseUpdates = false
      
      @_host = lastState?.host?.value or '0.0.0.0'
      @_xml = lastState?.xml?.value or null
      @_type = lastState?.type?.value or 'N/A'
      @_state = lastState?.state?.value or false
      
      @actions = _.cloneDeep @actions
      @attributes = _.cloneDeep @attributes
      
      @addAttribute('state',{
        description: "Device Presence"
        type: t.string
        acronym: 'Presence:'
        discrete: true
        hidden: false})
        
      @addAttribute('type',{
        description: "Device type"
        type: t.string
        acronym: 'Device type:'
        discrete: true})
      
      @addAttribute('host',{
        description: "Device network address"
        type: t.string
        acronym: 'Network address:'
        discrete: true})
      
      @addAction('playAudio', {
        description: "Stream a media resource to the DLNA device"
        params:
          resource:
            type: t.string})
      
      @_listener.on('deviceDiscovered', @updateDevice)
      @_listener.on('discoveryStopped', @_onDiscoveryEnd)
      
      super()

    destroy: ->
      @_listener.removeListener('discoveryStopped', @_onDiscoveryEnd)
      @_listener.removeListener('deviceDiscovered', @updateDevice)
      super()
    
    updateDevice: (config) =>
      return unless config.id is @id
      
      @_detected = true
      
      if !@_pauseUpdates
        @base.debug __("Updating network device information")
        
        @_setName(config.name)
        @_setHost(config.address)
        @_setXML(config.xml)
        @_setType(config.type)
        @_setState(true)
        @_setPresence(true)
    
    getType: () -> Promise.resolve(@_type)
    getHost: () -> Promise.resolve(@_host)
    getXML: () -> return @_xml
    getState: () -> Promise.resolve(@_presence)
    
    _setName: (name) ->
      return if name is @name
      @name = name
      @emit('name', name)
      
    _setHost: (host) ->
      return if host is @_host
      @_host = host
      @emit('host', host)
      
    _setXML: (xml) ->
      return if xml is @_xml
      @_xml = xml
      @emit('xml', xml)
    
    _setType: (type) ->
      return if type is @_type
      @_type = type
      @emit('type', type)
    
    _setState: (state) ->
      return if state is @_state
      @_state = state
      @emit('state', state)
      
    _onDiscoveryEnd: () =>
      @_setState(false) if !@_detected
      @_setPresence(false) if !@_detected
      @_detected = false
      
  return MediaPlayerDevice