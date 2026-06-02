platform :ios, '15.0'

target 'ClaudeBugPoC' do
  use_frameworks!

  # Networking
  pod 'Alamofire'

  # Layout
  pod 'SnapKit'

  # Image loading
  pod 'Kingfisher'

  # Firebase (matches the previous SPM setup)
  pod 'FirebaseFunctions'
  pod 'FirebaseFirestore'
  pod 'FirebaseAppCheck'
end

post_install do |installer|
  installer.generated_projects.each do |project|
    project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      end
    end
  end

  # Disable script sandboxing on the host project so CocoaPods'
  # framework-embedding script can write into the .app bundle.
  installer.aggregate_targets.each do |aggregate_target|
    aggregate_target.user_project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
      end
    end
    aggregate_target.user_project.save
  end
end
