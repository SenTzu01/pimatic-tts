# pimatic-tts
This plugin provides Text-to-Speech (TTS) functionality to Pimatic

## Features
- Provides a rule action allowing Pimatic to speak text over connected speakers
- Support for high quality speech synthesis in a large number of languages leveraging the Google TTS API
- More speech synthesis platforms may be supported in the future

### Rule syntax and examples: 
<b>Say "text with $pimatic-variables" using "< languageCode >" speed < n > repeat < n > interval < n ></b>
using "languageCode" (default: "en-GB") - defines the language to use for the speech synthesis . For supported languages and corresponding codes see: https://cloud.google.com/speech/docs/languages
speed <int> (default: 40) - defines the speed of the spoken text 
repeat <int> (default: 1) - defines the number of times the message should be spoken


- when trigger: $activity is "wakeup" then Say "Goodmorning everyone! I have set the home for waking up comfortably." using "en-GB" speed 40 repeat 1 interval 0

## Installation and Configuration:

### Install prerequisites as needed for your system:
- ALSA
- Alsa.h
- mpg321
- lame

Raspbian / Debian example to install prerequisites:
````sudo apt-get install alsa-utils libasound2-dev mpg321 lame````

### Installation

- Install Pimatic-tts via the Pimatic frontend (preferred), activate the plugin and restart Pimatic

Alternatively add it to the Plugin section of your config.json (be sure to stop Pimatic before making modifications!):
````json
{
  "plugin": "tts",
  "active": true
}
````

### Support

## Known issues:
- Pimatic-tts requires to be connected to have an internet connection in order to access Google cloud services

## Changelog:
- V0.0.1 - Initial version providing speech synthesis using the Google TTS API
