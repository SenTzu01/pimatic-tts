module.exports = {
  title: "Media player device config schemas"
  MediaPlayerDevice: {
    title: "Media player device config options"
    type: "object"
    properties:
      debug:
        description: "Debug this device."
        type: "boolean"
        default: false
        required: false
  }
}
