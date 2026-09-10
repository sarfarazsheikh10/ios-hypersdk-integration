import UIKit
import HyperSDK

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {

    /// Only used on iOS 12 and earlier; on iOS 13+ SceneDelegate owns the window.
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        if #unavailable(iOS 13.0) {
            let window = UIWindow(frame: UIScreen.main.bounds)
            window.rootViewController = UINavigationController(rootViewController: TPAPTestViewController())
            window.makeKeyAndVisible()
            self.window = window
        }
        return true
    }

    // iOS 12 redirect handling.
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        HyperSDKManager.handleRedirect(url, sourceApplication: options[.sourceApplication] as? String)
    }

    // MARK: - Scene lifecycle (iOS 13+)

    @available(iOS 13.0, *)
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}
