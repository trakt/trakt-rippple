platform :ios, '26.0'

inhibit_all_warnings!
use_frameworks!

post_install do |installer|
    installer.generated_projects.each do |project|
          project.targets.each do |target|
              target.build_configurations.each do |config|
                  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '26.0'
               end
          end
   end
end

target 'Rippple' do
    
    pod 'Haring', :git => 'https://github.com/kevincador/Haring.git'
    
    pod 'RPCircularProgress', '~> 0.4'
    
    pod 'Receiver', :git => 'https://github.com/kevincador/Receiver.git'
    
    pod 'HTMLEntities', :git => 'https://github.com/IBM-Swift/swift-html-entities.git'
    
    pod 'Emoji-swift'

    pod 'SpreadsheetView'

    pod 'AWSSNS'
    pod 'AWSDynamoDB'

end
