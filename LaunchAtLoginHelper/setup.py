import sys
import plistlib

urlScheme = sys.argv[1]
bundleIdentifier = sys.argv[2]

stringsOutput = 'LLStrings.h'
infoPlistOutput = 'LaunchAtLoginHelper/LaunchAtLoginHelper-Info.plist'
infoPlist = plistlib.readPlist('LaunchAtLoginHelper/LaunchAtLoginHelper-InfoBase.plist')

with open(stringsOutput, 'w') as strings:
    strings.write("""// strings used by LLManager and LaunchAtLoginHelper
//

#define LLURLScheme @"%(urlScheme)s"
#define LLHelperBundleIdentifier @"%(bundleIdentifier)s"
"""%locals())

infoPlist['CFBundleIdentifier'] = bundleIdentifier
plistlib.writePlist(infoPlist, infoPlistOutput)
