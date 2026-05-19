import Alamofire
import SwiftUI

struct VerdantWebContentShell: View {
    let urlString: String

    private var fullURL: String {
        urlString.hasPrefix("http") ? urlString : "https://\(urlString)"
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            WebContentView(url: fullURL)
        }
        .preferredColorScheme(.dark)
    }
}
