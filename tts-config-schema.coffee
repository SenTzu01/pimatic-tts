# #pimatic-tts plugin config options
module.exports = {
  title: "pimatic-tts plugin config options"
  type: "object"
  properties:
    debug:
      description: "Debug mode. Writes debug messages to the pimatic log, if set to true."
      type: "boolean"
      default: false
    language:
      description: "Language used for Speech"
      type: "string"
      default: "en-GB"
    speed:
      description: "Speed for speech, value between 0-100"
      type: "number"
      default: 40
    interval:
      description: "time between repeats of the same message in seconds"
      type: "number"
      default: 10
    repetitions:
      description: "Number of times the same message is repeated"
      type: "number"
      default: 1
}