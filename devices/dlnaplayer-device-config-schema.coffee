module.exports = {
  title: "DLNA device config schemas"
  DLNAPlayerDevice: {
    title: "DLNA Player device config options"
    type: "object"
    properties:
      debug:
        description: "Debug this device."
        type: "boolean"
        default: false
        required: false
  }
}
