import sys, os
import plistlib

urlScheme = sys.argv[1]
bundleIdentifier = sys.argv[2]

directory = os.path.dirname(os.path.abspath(__file__))

stringsOutput = os.path.join(directory, 'LLStrings.h')
infoPlistOutput = os.path.join(directory, 'LaunchAtLoginHelper/LaunchAtLoginHelper-Info.plist')
infoPlist = plistlib.readPlist(os.path.join(directory, 'LaunchAtLoginHelper/LaunchAtLoginHelper-InfoBase.plist'))

with open(stringsOutput, 'w') as strings:
    strings.write("""// strings used by LLManager and LaunchAtLoginHelper
//

#define LLURLScheme @"%(urlScheme)s"
#define LLHelperBundleIdentifier @"%(bundleIdentifier)s"
"""%locals())

infoPlist['CFBundleIdentifier'] = bundleIdentifier
plistlib.writePlist(infoPlist, infoPlistOutput)
