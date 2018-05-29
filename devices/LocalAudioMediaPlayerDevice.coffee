module.exports = (env) ->

  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  t = env.require('decl-api').types
  commons = require('pimatic-plugin-commons')(env)
  Volume = require('pcm-volume')
  Speaker = require('speaker')
  lame = require('lame')
  wav = require('wav')
  path = require('path')
  
  
  class LocalAudioMediaPlayerDevice extends env.devices.Device
    actions:
      playAudio:
        description: "Outputs Audio to the configured device"
        params:
          resource:
            type: t.string
    
    constructor: (@config, lastState, _null, @debug = false) ->
      @base = commons.base @, @config.class
      
      @_type = 'localAudio'
      
      @_volume = { 
        setting: @config.volume
        max: 150
        min: 1
        maxRel: 100
      }
      
      @_decoders = {
        mp3: lame.Decoder
        wav: wav.Reader
      }
      
      super()
    
    playAudio: (resource, volume = 40) =>
    
      return new Promise( (resolve, reject) =>
        type = path.ext(resource).slice(1).toLowerCase()
        
        decoder = @_decoders[type]
        
        decoder.on('format', (pcmFormat) =>
          @base.debug pcmFormat
          
          speaker = new Speaker(pcmFormat)
            .on('open', () =>
              @base.debug __("%s: Audio output started.", @id)
            )
        
            .on('error', (error) =>
              @base.resetLastError()
              @base.rejectWithErrorString Promise.reject, error, __("%s: Audio output failed. Error: %s", @id, error)
            )
        
            .on('finish', () =>
              msg = __("%s: Audio output completed successfully.", @id)
              @base.debug msg
              resolve msg
            )
            
          @_volControl = new Volume( @_pcmVolume( volume ) )
          
          decoder.pipe(@_volControl).pipe(speaker)
        )
        
        fs.createReadStream(resource).pipe(decoder)
      )
    
    getType: -> Promise.resolve @_type
    
    getMaxRelativeVolume: -> @_volume.maxRel
    getMaxVolume: -> @_volume.max
    getMinVolume: -> @_volume.min
    
    setVolumeLevel: (volume) -> @_volControl?.setVolume(@_pcmVolume(volume))
    
    _pcmVolume: (volume) -> return ( @_setVolumeWithinRange( volume ) / @getMaxRelativeVolume() * @getMaxVolume() / @getMaxRelativeVolume() ).toPrecision(2)
    
    _setVolumeWithinRange: (volume) ->
      if volume < @getMinVolume() then volume = @getMinVolume()
      if volume > @getMaxVolume() then volume = @getMaxVolume()
      return volume
    
    destroy: () ->
      @removeAllListeners('state')
      
      super()

  return LocalAudioMediaPlayerDevice