# pimatic-tts
This plugin provides Text-to-Speech (TTS) functionality to Pimatic

## Features
- Provides a rule action allowing Pimatic to speak text over connected speakers
- Currently supports the cloud based Google TTS API
- Plugin has been created to easily plugin other TTS platforms in future, as well as audio output devices
- Audio output to connected audio devices is achieved by streaming PCM audio to the ALSA backend on Debian/Ubuntu

## Rule syntax and examples: 

### Syntax
<b>Say "text with $pimatic-variables" using TTSDevice </b>

* TTSDevice - determines the Text-to-Speech device to use for speech synthesis. 

### Example
- when trigger: $activity is "wakeup" then Say "Goodmorning everyone! I have set the home for waking up comfortably." using google-tts-device

## Text-to-Speech Device configuration options:
* language <enum>       (default: en-GB)    - For supported languages and corresponding codes see: https://cloud.google.com/speech/docs/languages
* speed <0-100>         (default: 40)       - Velocity of the TTS voice 
* volume <0-100>        (default: 50)       - Sets gain volume for audio output of the TTS voice
* repeat <int>          (default: 1)        - Number of times a TTS voice message should be repeated
* interval <int>        (default: 10)       - Time in seconds between repeats of the same TTS voice message

## Installation and Configuration:

### Install prerequisites as needed for your system:
- ALSA
- Alsa.h (Needed for compiling modules on which pimatic-tts depends)
- mpg321
- lame

Raspbian / Debian example to install prerequisites:
````sudo apt-get install alsa-utils mpg321 lame libasound2-dev````

### Installation
- Install Pimatic-tts via the Pimatic frontend (preferred), activate the plugin and restart Pimatic
- Alternatively add it to the Plugin section of your config.json (be sure to stop Pimatic before making modifications!):
````json
{
  "plugin": "tts",
  "active": true
}
````

### Support

## Known issues:
- Google cloud limits the length of a TTS text string to 200 characters (should be sufficient for most use cases)
- Pimatic-tts (Google TTS API) requires an internet connection (which likely is the case already as you want to install the plugin)

## Changelog:
- V0.0.1 - Initial version providing speech synthesis using the Google TTS API

## Roadmap
- Implement an offline voice synthesizer next to the existing Google API
- Implement the ability to deliver speech through network connected devices (We should dream, shouldn't we)
