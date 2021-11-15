//
//  Copyright © 2019 Bandyer. All rights reserved.
//

import UIKit
import PushKit
import Intents
import CallKit
import Bandyer

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, CallClientObserver {

    var window: UIWindow?
    private var url: URL?

    // MARK: UISceneSession Lifecycle

    @available(iOS 13.0, *)
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    @available(iOS 13.0, *)
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        //Before we can get started, you must review your project configuration, and enable the required
        //app capabilities for CallKit and VoIP notifications.

        //Namely, you must enable "Background modes" capability
        //checking "Audio, AirPlay and Picture in Picture" and "Voice over IP" checkboxes on.
        //You must also enable "Push notifications" capability even if you use VoIP notifications only.

        //Privacy usage descriptions:
        //You must add NSCameraUsageDescription and NSMicrophoneUsageDescription to your app Info.plist file.
        //Those values are required to access microphone and camera. In this sample app, those values have been already added for you.

        //Consider also to add NSPhotoLibraryUsageDescription key into app Info.plist in case you want your users to upload photos on our services.

        //If your build target is less than iOS 11, please add iCloud entitlement with at least Key-value storage checked,
        //otherwise your app is going to crash anytime the user try to upload a document from iCloud.
        //In this sample app, this is already done for you inside 'Signing & Capabilities' tab of project settings.

        //To enable build on physical devices, you should disable bitcode on build settings tab of your target settings. In this sample app, this flag is already set for you.

        //CallKit:
        //CallKit framework must be linked to your app and it must linked as a required framework,
        //otherwise the app will have a weird behaviour when it is launched upon receiving a VoIP notification.
        //It is going to be launched, but the system is going to suspend it after few milliseconds.
        //In this example app, the CallKit framework has been already added for you.
        //Please check the project "Build Settings" tab under the "Other Linker Flags" directive that the CallKit
        //framework is linked as required framework

        //Here we are going to initialize the Bandyer SDK
        //The sdk needs a configuration object where it is specified which environment the sdk should work in.
        let config = Config()

        //Here we are telling the SDK we want to work in a sandbox environment.
        //Beware the default environment is production, we strongly recommend to test your app in a sandbox environment.
        config.environment = .sandbox

        //On iOS 10 and above this statement is not needed, the default configuration object
        //enables CallKit by default, it is here for completeness sake
        config.isCallKitEnabled = true

        //The following statement is going to change the name of the app that is going to be shown by the system call UI.
        //If you don't set this value during the configuration, the SDK will look for to the value of the
        //CFBundleDisplayName key (or the CFBundleName, if the former is not available) found in your App Info.plist

        config.nativeUILocalizedName = "My wonderful app"

        //The following statement is going to change the ringtone used by the system call UI when an incoming call
        //is received. You should provide the name of the sound resource in the app bundle that is going to be used as
        //ringtone. If you don't set this value, the SDK will use the default system ringtone.

        //config.nativeUIRingToneSound = "MyRingtoneSound"

        //The following statements are going to change the app icon shown in the system call UI. When the user answers
        //a call from the lock screen or when the app is not in foreground and a call is in progress, the system
        //presents the system call UI to the end user. One of the buttons gives the user the ability to get back into your
        //app. The following statements allows you to change that icon.
        //Beware, the configuration object property expects the image as an NSData object. You must provide a side
        //length 40 points square png image.
        //It is highly recommended to set this property, otherwise a "question mark" icon placeholder is used instead.

        let callKitIcon = UIImage(named: "callkit-icon")
        config.nativeUITemplateIconImageData = callKitIcon?.pngData()

        //The following statements will tell the BandyerSDK which type of handle the SDK should use with CallKit
        config.supportedHandleTypes = Set(arrayLiteral: NSNumber(integerLiteral: CXHandle.HandleType.generic.rawValue))
        //The following statement is going to tell the BandyerSDK which object it must forward device push tokens to when one is received.
        config.pushRegistryDelegate = self

        #error("Please set the payload keypath here")
        //This statement is going to tell the BandyerSDK where to look for incoming call information within the VoIP push notifications it receives
        config.notificationPayloadKeyPath = "SET YOUR PAYLOAD KEY PATH HERE"

        #error("Please initialize the Bandyer SDK with your App Id")
        //Now we are ready to initialize the SDK providing the app id token identifying your app in Bandyer platform.
        BandyerSDK.instance().initialize(withApplicationId: "PUT YOUR APP ID HERE", config: config)

        return true
    }
}

extension AppDelegate: PKPushRegistryDelegate {
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        let token = pushCredentials.tokenAsString
        debugPrint("Push credentials updated \(token), you should send them to your backend system")
    }
}

extension AppDelegate {
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        //When System call ui is shown to the user, it will show a "video" button if the call supports it.
        //The code below will handle the siri intent received from the system and it will hand it to the call view controller
        //if the controller is presented
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb {
            guard let url = userActivity.webpageURL else { return false }
            self.url = url
            if BandyerSDK.instance().callClient.isRunning() {
                let intent = JoinURLIntent(url: url)
                CallWindow.instance?.presentCallViewController(for: intent, completion: { [weak self] _ in
                    self?.url = nil
                })
            }
            return true
        }else {
            if #available(iOS 13.0, *) {
                guard let callIntent = userActivity.interaction?.intent as? INStartCallIntent else {
                    return false
                }
                guard let callController = visibleController(window?.rootViewController) as? CallViewController else {
                    return false
                }

                callController.handle(startCallIntent: callIntent)
                return true
            } else {
                if #available(iOS 10.0, *) {
                    guard let videoCallIntent = userActivity.interaction?.intent as? INStartVideoCallIntent else {
                        return false
                    }
                    guard let callController = visibleController(window?.rootViewController) as? CallViewController else {
                        return false
                    }

                    callController.handle(startVideoCallIntent: videoCallIntent)
                    return true
                }
            }
        }

        return false
    }

    func visibleController(_ controller: UIViewController?) -> UIViewController? {
        guard let visibleVC = controller else {
            return nil
        }

        if visibleVC.presentedViewController != nil {
            if let navController = visibleVC.presentedViewController as? UINavigationController {
                return visibleController(navController.viewControllers.last)
            }

            return visibleController(visibleVC.presentedViewController)
        }

        return visibleVC
    }

    func callClientDidStart(_ client: CallClient) {
        guard let url = self.url else { return }

        let intent = JoinURLIntent(url: url)

        if let window = CallWindow.instance {
            window.presentCallViewController(for: intent, completion: { [weak self] _ in
                self?.url = nil
            })
        } else {
            let window = CallWindow()
            window.presentCallViewController(for: intent, completion: { [weak self] _ in
                self?.url = nil
            })
        }
    }
}
