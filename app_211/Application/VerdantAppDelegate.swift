import Alamofire
import UIKit

final class VerdantAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        AppConfiguration.serverBaseURL = VPRuntimeLexicon.registrationBaseURL
        return true
    }
}
