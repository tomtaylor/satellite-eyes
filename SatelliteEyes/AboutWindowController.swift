import Cocoa
import SwiftUI

// MARK: - SwiftUI View

struct AboutView: View {
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    private let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)

            Text("Satellite Eyes")
                .font(.title)

            Text("Version \(version)\nBuild \(build)")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            CreditsView()
                .frame(height: 120)

            Button("Visit Homepage") {
                if let url = URL(string: "http://satelliteeyes.tomtaylor.co.uk/") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        .padding()
        .frame(width: 300)
    }
}

// MARK: - Credits RTF wrapper

private struct CreditsView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.drawsBackground = false

        if let url = Bundle.main.url(forResource: "Credits", withExtension: "rtf"),
           let attrString = try? NSAttributedString(url: url, options: [:], documentAttributes: nil) {
            textView.textStorage?.setAttributedString(attrString)

            // Size text view to fit content
            if let container = textView.layoutManager?.textContainers.first {
                textView.layoutManager?.glyphRange(for: container)
                let rect = textView.layoutManager?.usedRect(for: container) ?? .zero
                textView.setFrameSize(rect.size)
            }
        }

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {}
}

// MARK: - Window Controller

class AboutWindowController: NSWindowController {

    private static func makeWindow() -> NSWindow {
        let hostingController = NSHostingController(rootView: AboutView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "About Satellite Eyes"
        window.styleMask = [.titled, .closable]
        return window
    }

    override init(window: NSWindow?) {
        super.init(window: window ?? Self.makeWindow())
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.window = Self.makeWindow()
    }
}
