# pimatic-tts
This plugin provides Text-to-Speech (TTS) functionality to Pimatic

## Features
- Provides a rule action allowing Pimatic to speak text over connected speakers
- Currently supports the cloud based Google TTS and/or locally installed Pico2Wave on Linux
- Static speech resources can be cached on the local filesystem (Device config)
- Speech resources where the text input contains Pimatic variables will not be cached
- Define multiple devices for different TTS engines and/or output config
- Override device config values for Volume, Repeat and Repeat Interval on a rule by rule basis
- Audio output to connected audio devices is achieved by streaming PCM audio to the ALSA backend on Debian/Ubuntu

## Action syntax and examples: 

### Syntax
<b> <[say] | [speak]> "text with $pimatic-variables" using <[tts device id] | [TTS Device Name]> [[with volume nn] [repeating n times] [every n [s | seconds]]] </b>

"when trigger: $activity is "wakeup" then Say "Goodmorning everyone! I have set the home for waking up comfortably." using my-tts-device with volume 60"

## Installation and Configuration:

### Install prerequisites as needed for your system:
- ALSA
- Alsa.h (Needed for compiling modules on which pimatic-tts depends)
- mpg321
- mpg123
- lame
- Pico2Wave (For using offline Text-To-Speech)

Raspbian / Debian example to install prerequisites:
Google TTS :
````sudo apt-get install alsa-utils mpg123 mpg321 lame libasound2-dev````

Pico2Wave:
````sudo apt-get install libttspico0 libttspico-utils libttspico-data alsa-utils````

All:
````sudo apt-get install alsa-utils mpg123 mpg321 lame libasound2-dev libttspico0 libttspico-utils libttspico-data````

### Installation
- Install prerequisites
- Install Pimatic-tts via the Pimatic frontend, activate the plugin and restart Pimatic
- Alternatively add it to the Plugin section of your config.json, after which the plugin will be downloaded and installed during Pimatic startup (be sure to stop Pimatic before making modifications!):
````json
"plugins": [
  {
    "plugin": "tts",
    "active": true
  },
  ...
````

### Support

## Known issues:
- Google cloud limits the length of a TTS text string to 200 characters (should be sufficient for most use cases)
- Pimatic-tts (Google TTS API) requires an internet connection (which likely is the case already as you want to install the plugin)

## Roadmap
- Implement the ability to deliver speech through network connected devices (We should dream, shouldn't we)
