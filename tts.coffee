# The amazing dash-button plugin
module.exports = (env) ->

  Promise = env.require 'bluebird'
  commons = require('pimatic-plugin-commons')(env)
  M = env.matcher
  tts = require('google-tts-api')
  mplayer = require('player')
  
  class TextToSpeechPlugin extends env.plugins.Plugin
    
    init: (app, @framework, @config) =>
      @debug = @config.debug || false
      @base = commons.base @, 'Plugin'
      
      @player = new mplayer()
      @player.on('error', (error) =>
        if 'No next song was found' is error
          return Promise.resolve __(error) 
        else
          return Promise.reject error
      )
      @player.on('playend', (item) =>
        return Promise.resolve __("%s was played", item)
      )
        
      @framework.ruleManager.addActionProvider(new TextToSpeechActionProvider(@framework, @config))
      
    toSpeech: (string) =>
      tts(string, @config.language, 1).then( (url) =>
        @player.add(url)
        @player.play()
      ).catch( (err) =>
        console.error(err)
      )
      
  class TextToSpeechActionProvider extends env.actions.ActionProvider
    
    constructor: (@framework, @config) ->
      
    parseAction: (input, context) =>
      retVal = null
      ttsString = null
      fullMatch = no

      setString = (m, tokens) => ttsString = tokens
      onEnd = => fullMatch = yes
      
      m = M(input, context)
        .match("Speak ")
        .matchStringWithVars(setString)
      
      if m.hadMatch()
        match = m.getFullMatch()
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new TextToSpeechActionHandler(@framework, ttsString)
        }
      else
        return null
        
  class TextToSpeechActionHandler extends env.actions.ActionHandler
  
    constructor: (@framework, @ttsString) ->
      
    executeAction: (simulate) =>
      return new Promise( (resolve, reject) =>
        console.log(@ttsString)
        @framework.variableManager.evaluateStringExpression(@ttsString).then( (string) =>
          if simulate
            # just return a promise fulfilled with a description about what we would do.
            return __("would convert Text to Speech: \"%s\"", string)
          else
            results = []
            speakText = (text) =>
              if text.length > 200
                env.logger.debug __("'%s' is more than 200 characters", text)
                results.push Plugin.toSpeech(text.split(0, 200))
                speakText(text.split(n+201))
              else
                env.logger.debug __("'%s' is less than than 200 characters", text)
                results.push Plugin.toSpeech(text)
            speakText(string)
            
            Promise.all(results).then( (values) =>
              resolve __("'%s' was spoken", string)
            )
        )
      )

  Plugin = new TextToSpeechPlugin
  return Plugin