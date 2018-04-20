module.exports = {
  title: "DLNA device config schemas"
  DLNAPlayerDevice: {
    title: "DLNA Player device config options"
    type: "object"
    properties:
      identifier:
        description: "Identifier or IP Address that is matched against the found DLNARenderer."
        type: "string"
        default: "DLNA device"
        required: false
        
  }
}
