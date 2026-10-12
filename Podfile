platform :ios, '17.0'
project 'MadeRoom.xcodeproj'
workspace 'MadeRoom'

# All third-party dependencies are managed through CocoaPods.
target 'MadeRoom' do
  use_frameworks! :linkage => :static
  pod 'IQKeyboardManagerSwift', '8.0.3'
  pod 'FirebaseAuth'
  pod 'FirebaseCore'
  pod 'FirebaseFirestore'
  pod 'BoringSSL-GRPC', :podspec => 'tools/podspecs/BoringSSL-GRPC.podspec.json'

  target 'MadeRoomTests' do
    inherit! :search_paths
  end

  target 'MadeRoomUITests' do
    inherit! :search_paths
  end
end

# Xcode 27 no longer supports the older deployment targets in some podspecs.
# Keep generated dependency targets compatible with the app's iOS 17 minimum.
post_install do |installer|
  minimum_ios = Gem::Version.new('17.0')
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      current = config.build_settings['IPHONEOS_DEPLOYMENT_TARGET']
      if current.nil? || Gem::Version.new(current) < minimum_ios
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = minimum_ios.to_s
      end
    end
  end
end



