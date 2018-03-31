module.exports = {
  title: "Google TTS device config schemas"
  GoogleTTSDevice: {
    title: "Google device configuration options"
    type: "object"
    properties:
      tmpDir:
        description: "Directory used for storing converted speech files"
        type: "string"
        required: false
        default: "/tmp"
      language:
        description: "Language used for synthesized speech. See README for available languages"
        type: "string"
        enum: []
        required: false
        default: "en-GB"
      speed:
        description: "Sets speech velocity: Value between 0-100"
        type: "number"
        default: 40
        required: false
      volume:
        description: "Sets audio volume for speech: Value between 0-100"
        type: "number"
        default: 50
        required: false
      repeat:
        description: "Sets the number of times a speech message is repeated"
        type: "number"
        default: 1
        required: false
      interval:
        description: "Time between a repeated voice message"
        type: "number"
        default: 10
        required: false
      
  }
}