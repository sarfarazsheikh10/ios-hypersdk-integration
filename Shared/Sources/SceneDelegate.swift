import UIKit
import HyperSDK

@available(iOS 13.0, *)
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UINavigationController(rootViewController: TPAPTestViewController())
        window.makeKeyAndVisible()
        self.window = window

        connectionOptions.urlContexts.forEach { handle($0) }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        URLContexts.forEach { handle($0) }
    }

    private func handle(_ context: UIOpenURLContext) {
        HyperSDKManager.handleRedirect(context.url,
                                       sourceApplication: context.options.sourceApplication)
    }
}
