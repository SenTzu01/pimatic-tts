# The amazing dash-button plugin
module.exports = (env) ->

  Promise = env.require 'bluebird'
  commons = require('pimatic-plugin-commons')(env)
  M = env.matcher
  TTS = require('google-tts-api')
  Player = require('player')
  
  class TextToSpeechPlugin extends env.plugins.Plugin
    
    init: (app, @framework, @config) =>
      @debug = @config.debug || false
      @base = commons.base @, 'Plugin'
      @queue = []
      @player = null
      
      @framework.ruleManager.addActionProvider(new TextToSpeechActionProvider(@framework, @config))
    
    playVoice:() =>
      voice = @queue.shift()
      @player = new Player(voice)
      @player.play()
      
      @player.on('playend', (item) =>
        @player = null
        if @queue.length > 0
          return @playVoice()
        msg = __("%s was played", voice)
        env.logger.debug __("Plugin::playVoice::player.on.playend - %s", msg)
        return Promise.resolve msg
      )

      @player.on('error', (error) =>
        @player = null
        if 'No next song was found' is error
          if @queue.length > 0
            return @playVoice()
          msg = __("%s was played", voice)
          env.logger.debug __("Plugin::playVoice::player.on.error - %s", msg)
          return Promise.resolve msg
        else
          return Promise.reject error
      )
        
    
    toSpeech: (text, language, speed) =>
      language ?= @config.language
      speed ?= @config.speed
      env.logger.debug __("Plugin::toSpeech - text: %s, language: %s, speed: %s", text, language, speed)
      TTS(text, language, speed/100).then( (url) =>
        @queue.push url
        if @player?
          env.logger.debug __("Plugin::toSpeech - @player: %s", @player?)
          return Promise.resolve __("%s was added to queue", text)
        return @playVoice()
        
      ).catch( (err) =>
        env.logger.error err
      )
      
  class TextToSpeechActionProvider extends env.actions.ActionProvider
    
    constructor: (@framework, @config) ->
      
    parseAction: (input, context) =>
      retVal = null
      text = {value: null, language: null, speed: null, repetitions: 1, delay: null}
      fullMatch = no

      setString = (m, tokens) => text.value = tokens
      setSpeed = (m, tokens) => text.speed = tokens
      setRepetitions = (m, tokens) => text.repetitions = tokens
      setIntervalTime = (m, tokens) => text.interval = tokens
      setLanguage = (m, tokens) => text.language = tokens
      onEnd = => fullMatch = yes
      
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
        

      if m.hadMatch()
        match = m.getFullMatch()
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new TextToSpeechActionHandler(@framework, text)
        }
      else
        return null
        
  class TextToSpeechActionHandler extends env.actions.ActionHandler
  
    constructor: (@framework, @text) ->
      @results = []
      
      env.logger.debug __("TextToSpeechActionHandler::constructor() - @text.value: %s, @text.language: %s", @text.value, @text.language)
      
    textToSpeech: (text, lang, speed) =>
      if text.length > 200
        env.logger.debug __("'%s' is more than 200 characters", text)
        @results.push Plugin.toSpeech(text.split(0, 200), lang, speed)
        @textToSpeech(text.split(n+201))
      else
        env.logger.debug __("'%s' is less than than 200 characters", text)
        @results.push Plugin.toSpeech(text, lang, speed)
      return @results
    
    repeatMessage: (text, lang, speed, reps, delay) =>
      repetitions = []
      i = 1
      interval = setInterval(( =>
        if i <= reps
          repetitions.push @textToSpeech(text, lang, speed)
        else
          clearInterval(interval)
        i++
      ), delay)
      
      Promise.all(repetitions).then( (results) =>
        return Promise.resolve __("'%s' was spoken using %s", text, @text.language)
      ).catch(Promise.AggregateError, (err) =>
        return @base.rejectWithErrorString Promise.reject, __("'%s' was NOT spoken %s times", text, @text.repeat)
      )
    
    executeAction: (simulate) =>
      env.logger.debug __("TextToSpeechActionHandler::executeAction() - @text.value: %s, @text.language: %s", @text.value, @text.language)
      if simulate
        # just return a promise fulfilled with a description about what we would do.
        return __("would convert Text to Speech: \"%s\"", @text.value)
      else
        @results = []
        @framework.variableManager.evaluateStringExpression(@text.value).then( (text) =>
          env.logger.debug __("TextToSpeechActionHandler::@framework.variableManager.evaluateStringExpression: - string: %s, @text.language: %s, speed: %s, repeat: %s, delay: %s", text, @text.language, @text.speed, @text.repetitions, @text.delay)
          return @repeatMessage(text, @text.language, @text.speed, @text.repetitions, @text.delay)
        )
  Plugin = new TextToSpeechPlugin
  return Plugin