import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    GMSServices.provideAPIKey("AIzaSyAKmSfD5hcq73jJ8T1k4Vj0UJIMLtZO42A")
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
