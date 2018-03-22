module.exports = {
  title: "Google Speech Synthesizer device config schemas"
  GoogleSpeechSynthesisDevice: {
    title: "Google Speech Synthesizer device configuration options"
    type: "object"
    properties:
      language:
        description: "Language used for Speech"
        type: "string"
        default: "en-GB"
        required: true
      speed:
        description: "Speed for speech, value between 0-100"
        type: "number"
        default: 40
        required: false
      interval:
        description: "time between repeats of the same message in seconds"
        type: "number"
        default: 10
        required: false
      repetitions:
        description: "Number of times the same message is repeated"
        type: "number"
        default: 1
  }
}