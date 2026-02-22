# Satellite Eyes

![Satellite Eyes](https://user-images.githubusercontent.com/836375/31194770-0950b980-a8fd-11e7-8108-9a08555a0832.png)

Satellite Eyes is a macOS application that sits in your system tray (next to the clock) and automatically updates your desktop wallpaper to the satellite or map view overhead.

It's available for download at [http://satelliteeyes.tomtaylor.co.uk](http://satelliteeyes.tomtaylor.co.uk).

## Building

Satellite Eyes is a Swift project targeting macOS 13.0. Open `SatelliteEyes.xcworkspace` in Xcode to build. Dependencies are managed via SwiftPM and will resolve automatically.

You might need to update the project to use your own team and certificates, but please don’t commit these changes.

Many thanks to the following folks for their contributions to Satellite Eyes:

* [James Bridle](https://github.com/stml) for the icon.
* [Justin Hileman](https://github.com/bobthecow) for work on the image effects
  pipeline.
* [Alex Forey](https://github.com/alfo) for Retina compatible icons.

## Contributions

If you want to contribute a feature or a bug fix to SE, that'd be great. I'll do my best to review them and include them where possible. Contributions would be especially appreciated for:

* Controls for configuring each Space independently
* More map styles

If you are planning to land a major feature, please raise an issue to discuss it first.
