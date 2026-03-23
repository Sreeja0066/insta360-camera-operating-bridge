Pod::Spec.new do |s|
  s.name             = 'INSCameraSDK'
  s.version          = '1.9.2'
  s.summary          = 'Insta360 Camera SDK'
  s.homepage         = 'https://github.com/insta360'
  s.license          = { :type => 'Custom', :text => 'Copyright Insta360' }
  s.author           = { 'Insta360' => 'sdk@insta360.com' }
  s.source           = { :path => '.' }

  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'

  # Automatically include ALL frameworks in this folder (including Carthage downloads)
  s.vendored_frameworks = '*.xcframework'
  
  s.frameworks       = 'Foundation', 'UIKit', 'AVFoundation', 'CoreMedia', 'CoreVideo', 'CoreGraphics', 'Photos'
  s.libraries        = 'c++', 'z'
  
  # Ensure the module is created for Swift
  s.module_name      = 'INSCameraSDK'

  # Robustly define TO_B_SDK=1 to bypass the missing NvEffectSdkCore Meishe SDK compilation dependency in Insta360 headers
  s.pod_target_xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' => 'TO_B_SDK=1' }
  s.user_target_xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' => 'TO_B_SDK=1' }
end
