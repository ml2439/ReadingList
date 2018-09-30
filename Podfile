# Uncomment the next line to define a global platform for your project
platform :ios, '10.3'
use_frameworks!

target 'ReadingList' do
  pod 'DZNEmptyDataSet', '~> 1.8'
  pod 'SwiftyJSON', '~> 4.0'
  pod 'Eureka', '~> 4.3'
  pod 'ImageRow', '~> 3.0'
  pod 'SVProgressHUD', '~> 2.2'
  pod 'SwiftyStoreKit', '~> 0.13'
  pod 'CHCSVParser', :git => 'https://github.com/davedelong/CHCSVParser.git'
  pod 'PromisesSwift', '~> 1.2'
  pod 'SimulatorStatusMagic', :configurations => ['Debug']
  pod 'Fabric'
  pod 'Crashlytics'
  pod 'Firebase/Core'
  pod 'ReachabilitySwift'

  target 'ReadingList_UnitTests' do
    inherit! :search_paths
  end
  target 'ReadingList_UITests' do
    inherit! :complete
  end
  target 'ReadingList_Screenshots' do
    inherit! :complete
  end

  # Use Swift 4.0 instead of 4.2 for some Pods
  post_install do |installer|
  	myTargets = ['ImageRow']
  	installer.pods_project.targets.each do |target|
  			target.build_configurations.each do |config|
          if myTargets.include? target.name
  				  config.build_settings['SWIFT_VERSION'] = '4.0'
  			  end
  		end
  	end
    # See https://github.com/CocoaPods/CocoaPods/issues/8063 and https://github.com/CocoaPods/CocoaPods/issues/4439
    installer.pods_project.build_configurations.each do |config|
      if config.name == 'Release'
        config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Owholemodule'
      else
        config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
      end
    end
  end
end
