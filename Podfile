source 'https://github.com/CocoaPods/Specs.git'
platform :osx, '10.8'

# Ignore pod warnings
inhibit_all_warnings!

workspace 'lukesolomon/desktop/Extra\ Curriculars/satellite-eyes/Workspace.xcworkspace'

def shared_target_pods
	pod 'Reachability',  '~> 3.1.0'
	pod 'CocoaLumberjack', '~> 1.9.1'
	pod 'AFNetworking', '~> 1.3'
	pod 'Sparkle', '~> 1.15.1’
end

target :’Satellite Eyes’ do
    shared_target_pods
end