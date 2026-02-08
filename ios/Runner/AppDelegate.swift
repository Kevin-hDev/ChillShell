import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  /// Vue de masquage affichée quand l'app passe en arrière-plan (protection screenshot)
  private var privacyScreen: UIView?
  /// Protection activée par défaut (contrôlée depuis Flutter via MethodChannel)
  private var screenshotProtectionEnabled: Bool = true

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Configurer le MethodChannel pour contrôler la protection screenshot
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.vibeterm/security",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] (call, result) in
        if call.method == "setScreenshotProtection" {
          if let enabled = call.arguments as? Bool {
            self?.screenshotProtectionEnabled = enabled
          }
          result(nil)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Masque le contenu de l'app quand elle passe en arrière-plan
  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    guard screenshotProtectionEnabled else { return }
    let screen = UIView(frame: window?.bounds ?? UIScreen.main.bounds)
    screen.backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1.0) // #0F0F0F
    screen.tag = 9999
    window?.addSubview(screen)
    privacyScreen = screen
  }

  /// Retire l'écran de masquage quand l'app revient au premier plan
  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    privacyScreen?.removeFromSuperview()
    privacyScreen = nil
  }
}
