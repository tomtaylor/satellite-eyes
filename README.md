Satellite Eyes
==

Satellite Eyes is a small OS X application that sits in your system tray (next
to the clock) and automatically updates your desktop wallpaper to the satellite
or map view overhead.

It's available for download at
[http://satelliteeyes.tomtaylor.co.uk](http://satelliteeyes.tomtaylor.co.uk).

Building
--

Satellite Eyes (SE) is an Xcode 4.4 compatible project, targeting 10.7 upwards.
It seems to work best on 10.8, as 10.7 has a few bugs in Location Services that
I haven't got round to looking at properly.

It's not very well documented, sorry, but it's not a big codebase, so I'm sure
you'll work it out.

To build for Debug:

1. Create a new Code Signing cert named "Mac Developer".

2. Set up the LaunchAtLoginHelper:
   
   ```bash
   cd LaunchAtLoginHelper
   python setup.py satelliteeyes uk.co.tomtaylor.SatelliteEyes
   ```

3. Build!

Contributions
--

If you want to contribute a feature or a bug fix to SE, that'd be great. I'll
do my best to review them and include them where possible. Contributions would
be especially appreciated for:

* Ability to display imagery from interesting places around the world.
* Controls for configuring each Space independently (the official APIs to do
  this are deprecated in 10.8).
* Improving the visual appearance of the preferences pane
* More map styles

If you are planning to land a major feature, please raise an issue to discuss
it first.
