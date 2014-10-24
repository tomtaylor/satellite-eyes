When creating a sandboxed app `LSSharedFileListInsertItemURL` can no longer be used to launch the app at startup. Instead `SMLoginItemSetEnabled` should be used with a helper app inside the main app's bundle that launches the main app. **LaunchAtLoginHelper** is that helper app, it is designed to be as easy as possible to integrate into the main app to allow it to launch at login when sandboxed.

A lot of research was put into this helper app. For example [Apple's docs](http://developer.apple.com/library/mac/#documentation/Security/Conceptual/AppSandboxDesignGuide/DesigningYourSandbox/DesigningYourSandbox.html#//apple_ref/doc/uid/TP40011183-CH4-SW3) state that `LSRegisterURL` should be used to register the helper app, however this never seemed to work and after further digging it turns out this is a [typo in the docs](https://devforums.apple.com/message/647212#647212). Many examples I found online used `NSWorkspace launchApplication:` to launch the main app, however this was blocked by sandboxing so a url scheme is used instead.

**LaunchAtLoginHelper** calls the main app's scheme twice, once to launchg the app and then again with `launchedAtLogin` so the main app can know if it has been launched at login. For example [Play by Play](http://playbyplayapp.com) uses this to hide the app if it was launched at login.

This project contains a [sample app](https://github.com/kgn/LaunchAtLoginHelper/tree/master/LaunchAtLoginSample) to demonstrate how the main app should be configured and how to setup a checkbox to enable and disable launching at login.

# How to use

First download or even better submodule **LaunchAtLoginHelper**. To clone the repository as a submodule use the following commands:

```
$ cd <main_app_project>
$ git clone --recursive https://github.com/kgn/LaunchAtLoginHelper.git
```

**LaunchAtLoginHelper** uses a url scheme to launch the main app, if the main app doesn't have a url scheme yet add one.

![](http://kgn.github.com/content/launchatlogin/url_scheme.png)

There are two files missing from this repo that are specific to your instance of the helper app. To generate these files run the `setup.py` python script and pass in the url scheme to launch the main app and the bundle identifier of the helper app, this is usually based of of the bundle identifier of the main app but with *Helper* added onto the end.

```
$ cd LaunchAtLoginHelper
$ python setup.py <main_app_url_scheme> <helper_app_bundle_identifier>
```

For the sample code the above will look like this:

```
$ cd LaunchAtLoginHelper
$ python setup.py launchatloginsample com.InScopeApps.ShellTo.LaunchAtLoginHelper
```

This will create `LLStrings.h` which is used in both the helper app and the main app and contains `#define`'s for the url scheme and the helper app's bundle identifier. `LaunchAtLoginHelper-Info.plist` is also created for the helper app with it's custom bundle identifier filled in.

Once these two files are generated it's time to add **LaunchAtLoginHelper** to the main app. Drag `LaunchAtLoginHelper.xcodeproj`, `LLStrings.h`, `LLManager.h`, and `LLManager.m` to the main app's project.

![](http://kgn.github.com/content/launchatlogin/drag_drop_file.png)

Next go to the *Build Phases* for the main app and add **LaunchAtLoginHelper** as a *Target Dependency* and create a new *Copy Files Build Phase*. Set the *Destination* of this build phase to `Wrapper` and the *Subpath* to `Contents/Library/LoginItems`.

![](http://kgn.github.com/content/launchatlogin/build_phases.png)

Lastly add `ServiceManagement.framework` to the main app.

Once this is done use `LLManager` to enable and disable launching at login! [**LaunchAtLoginSample**](https://github.com/kgn/LaunchAtLoginHelper/blob/master/LaunchAtLoginSample/LLAppDelegate.m) shows how to hook this up to a checkbox.

``` obj-c
#import "LLManager.h"

[LLManager launchAtLogin] // will the app launch at login?
[LLManager setLaunchAtLogin:YES] // set the app to launch at login
```

# Bindings

The `LLManager` class supports KVO and Cocoa Bindings. This allows for a completely code-free implementaion of this class. To get started, open the Interface Builder document in which you plan to create a login toggle. Drag a generic `NSObject` from the Utilities pane, and drop it onto your canvas. Select the newly created object, and open the Identity inspector tab in the Utilities pane. Change the class from `NSObject` to `LLManager`. Now, select to your login toggle (checkbox) and open the Bindings inspector in the Utilities pane. Expand `Value`, check the "Bind to", and select the name of the `LLManager` object you created earlier. Set the key path to `self.launchAtLogin`. You're done!

---

Special thanks to [Curtis Hard](http://www.geekygoodness.com) for offering some much needed advice on this project.