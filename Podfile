# Uncomment the next line to define a global platform for your project
platform :ios, '10.3'
use_frameworks!

def all_pods
  pod 'DZNEmptyDataSet', '~> 1.8'
  pod 'SwiftyJSON', '~> 4.0'
  pod 'Eureka', :git => 'https://github.com/xmartlabs/Eureka.git', :commit => 'ec14ae696e' # to use customised UIPickerViews
  pod 'ImageRow', '~> 3.0'
  pod 'SVProgressHUD', '~> 2.2'
  pod 'SwiftyStoreKit', '~> 0.13'
  pod 'CHCSVParser', :git => 'https://github.com/davedelong/CHCSVParser.git'
  pod 'PromisesSwift', '~> 1.2'
  pod 'SimulatorStatusMagic', :configurations => ['Debug']
  pod 'Fabric'
  pod 'Crashlytics'
  pod 'Firebase/Core'
  pod 'SwiftLint'
end

target 'ReadingList' do
  all_pods
end
target 'ReadingList_UITests' do
  all_pods
end
target 'ReadingList_UnitTests' do
  all_pods
end
target 'ReadingList_Screenshots' do
  all_pods
end
