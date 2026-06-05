import SwiftUI

@main
struct MidivanaApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}

struct WebContainerView: View {
  var body: some View {
    Group {
      if let url = Bundle.main.url(forResource: "index", withExtension: "html"),
         let html = try? String(contentsOf: url, encoding: .utf8) {
        WebView(html: html, baseURL: url.deletingLastPathComponent())
      } else {
        VStack(spacing: 12) {
          Text("Missing index.html")
            .font(.headline)
          Text("Make sure Resources/index.html is bundled in the app.")
            .font(.subheadline)
        }
        .padding()
      }
    }
  }
}
