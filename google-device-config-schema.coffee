module.exports = {
  title: "Google TTS device config schemas"
  GoogleTTSDevice: {
    title: "Google  device configuration options"
    type: "object"
    properties:
      language:
        description: "Language used for Speech"
        type: "string"
        enum: []
        required: false
        default: "en-GB"
      speed:
        description: "Speed for speech, value between 0-100"
        type: "number"
        default: 40
        required: false
      volume:
        description: "Volume for audio, value between 0-100"
        type: "number"
        default: 50
        required: false
      repeat:
        description: "Number of times the same message is repeated"
        type: "number"
        default: 1
        required: false
      interval:
        description: "time between repeats of the same message in seconds"
        type: "number"
        default: 10
        required: false
      
  }
}