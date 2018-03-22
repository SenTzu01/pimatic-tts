# The amazing dash-button plugin
module.exports = (env) ->

  Promise = env.require 'bluebird'
  commons = require('pimatic-plugin-commons')(env)
  M = env.matcher
  Synthesize = require('google-tts-api')
  Player = require('player')
  
  class TextToSpeechPlugin extends env.plugins.Plugin
    
    init: (app, @framework, @config) =>
      @debug = @config.debug || false
      @base = commons.base @, 'Plugin'
      
      @framework.ruleManager.addActionProvider(new TextToSpeechActionProvider(@framework, @config))
    
    playVoiceResource:(resource, volume) =>
      player = new Player(resource, {downloads: '/var/tmp'})
        .on('playing', (item) =>
          player.setVolume(volume)
        )
        .on('playend', (item) =>
          return new Promise( (resolve, reject) =>
            player = null
            msg = __("%s was played", resource)
            env.logger.debug msg
            resolve msg
          )
        )
        .on('error', (error) =>
          return new Promise( (resolve, reject) =>
            player = null
            if 'No next song was found' is error
              msg = __("%s was played", resource)
              env.logger.debug msg
              resolve msg
            else
              env.logger.error error
              reject error
          )
        )
      player.play()
        
    
    getVoiceResource: (text, language, speed) =>
      env.logger.debug __("Plugin::toSpeech - text: %s, language: %s, speed: %s", text, language, speed)
      return new Promise( (resolve, reject) =>
        Synthesize(text, language, speed/100).then( (url) =>
          resolve url
        ).catch( (err) =>
          env.logger.error err
          reject err
        )
      )
      
  class TextToSpeechActionProvider extends env.actions.ActionProvider
    
    constructor: (@framework, @config) ->
      
    parseAction: (input, context) =>
      retVal = null
      text = {value: null, language: null, speed: null, repetitions: 1, delay: null, volume: 50}
      fullMatch = no

      setString = (m, tokens) => text.value = tokens
      setLanguage = (m, tokens) => text.language = tokens
      setSpeed = (m, tokens) => text.speed = tokens
      setRepetitions = (m, tokens) => text.repetitions = tokens
      setIntervalTime = (m, tokens) => text.interval = tokens*1000
      setVolume = (m, tokens) => text.volume = tokens/100
      
      m = M(input, context)
        .match("Say ")
        .matchStringWithVars(setString)
        .match(" using ")
        .match(["nl-NL", "en-GB"], setLanguage)
        .match(" speed ")
        .matchNumber(setSpeed)
        .match(" repeat ")
        .matchNumber(setRepetitions)
        .match(" interval ")
        .matchNumber(setIntervalTime)
        .match(" volume ")
        .matchNumber(setVolume)
        

      if m.hadMatch()
        match = m.getFullMatch()
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new TextToSpeechActionHandler(@framework, @config, text)
        }
      else
        return null
        
  class TextToSpeechActionHandler extends env.actions.ActionHandler
  
    constructor: (@framework, @config, @text) ->
      env.logger.debug __("TextToSpeechActionHandler::constructor() - @text.value: %s, @text.language: %s", @text.value, @text.language)
    
    executeAction: (simulate) =>
      env.logger.debug __("TextToSpeechActionHandler::executeAction() - @text.value: %s, @text.language: %s", @text.value, @text.language)
      if simulate
        # just return a promise fulfilled with a description about what we would do.
        return __("would convert Text to Speech: \"%s\"", @text.value)
      
      else
        return new Promise( (resolve, reject) =>
          @framework.variableManager.evaluateStringExpression(@text.value).then( (text) =>
            env.logger.debug __("TextToSpeechActionHandler - text: %s", text)
            @base.rejectWithErrorString Promise.reject, __("'%s' is %s characters. A maximum of 200 characters is allowed.", text, text.length) if text.length > 200
            
            language = @text.language ? @config.language
            delay = @text.interval ? @config.interval
            speed = @text.speed ? @config.speed
            reps = @text.repetitions ? @config.repetitions
            volume = @text.volume ? @config.volume/100
            
            Plugin.getVoiceResource(text, language, speed).then( (url) =>
              repetitions = []
              
              repetitions.push Plugin.playVoiceResource(url, volume.toPrecision(1))
              i = 2
              interval = setInterval(( =>
                if i <= reps
                  repetitions.push Plugin.playVoiceResource(url, volume.toPrecision(1))
                if i >= reps
                  clearInterval(interval)
                  Promise.all(repetitions).then( (results) =>
                    resolve __("'%s' was spoken %s times", text, reps)
                  ).catch(Promise.AggregateError, (err) =>
                    @base.rejectWithErrorString Promise.reject, __("'%s' was NOT spoken %s times", text, reps)
                  )
                i++
              ), delay)
            )
          )
        )
  Plugin = new TextToSpeechPlugin
  return Plugin