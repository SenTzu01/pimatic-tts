module.exports = {
  title: "TTS device config schemas"
  GoogleTTSDevice: {
    title: "Google device configuration options"
    type: "object"
    properties:
      enableCache:
        description: "Cache audio resources for previously converted text"
        type: "boolean"
        default: true
        required: false
      tmpDir:
        description: "Directory used for storing cached audio resources"
        type: "string"
        default: "/tmp"
        required: false
      language:
        description: "Language used for synthesized speech. See README for available languages"
        type: "string"
        enum: []
        default: "en-GB"
        required: false
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
  PicoTTSDevice: {
    title: "Google device configuration options"
    type: "object"
    properties:
      enableCache:
        description: "Cache audio resources for previously converted text"
        type: "boolean"
        default: true
        required: false
      tmpDir:
        description: "Directory used for storing cached audio resources"
        type: "string"
        default: "/tmp"
        required: false
      executable:
        description: "Full path of the Pico2Wave executable"
        type: "string"
        default: "/usr/bin/pico2wave"
        required: false
      language:
        description: "Language used for synthesized speech. See README for available languages"
        type: "string"
        enum: []
        default: "en-GB"
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