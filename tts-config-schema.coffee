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
}