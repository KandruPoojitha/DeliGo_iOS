platform :ios, '15.0'

target 'DeliGo_IOS' do
  use_frameworks!

  # Firebase
  pod 'Firebase', '~> 10.0'
  pod 'FirebaseCore'
  pod 'FirebaseAuth'
  pod 'FirebaseFirestore'
  pod 'FirebaseStorage'
  pod 'FirebaseAnalytics'
  pod 'FirebaseAppCheck'
  pod 'GTMSessionFetcher'
  pod 'RecaptchaInterop'
  
  # Fix for missing modules
  pod 'FirebaseAppCheckInterop'
  pod 'FirebaseAuthInterop'
  pod 'FirebaseCoreExtension'
  pod 'FirebaseAuthInternal'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end 