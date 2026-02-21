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

            Button("Visit Homepage") {
                if let url = URL(string: "http://satelliteeyes.tomtaylor.co.uk/") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        .padding()
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Credits RTF wrapper

private struct CreditsView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainer?.lineFragmentPadding = 0
        textView.isVerticallyResizable = false

        if let url = Bundle.main.url(forResource: "Credits", withExtension: "rtf"),
           let attrString = try? NSAttributedString(url: url, options: [:], documentAttributes: nil) {
            let mutable = NSMutableAttributedString(attributedString: attrString)
            let fullRange = NSRange(location: 0, length: mutable.length)
            mutable.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
            mutable.enumerateAttribute(.paragraphStyle, in: fullRange) { value, range, _ in
                guard let style = value as? NSParagraphStyle else { return }
                let updated = style.mutableCopy() as! NSMutableParagraphStyle
                updated.headIndent = 0
                updated.firstLineHeadIndent = 0
                mutable.addAttribute(.paragraphStyle, value: updated, range: range)
            }
            textView.textStorage?.setAttributedString(mutable)
        }

        return textView
    }

    func updateNSView(_ nsView: NSTextView, context: Context) {}

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSTextView, context: Context) -> CGSize? {
        let width = proposal.width ?? 300
        nsView.textContainer?.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
        nsView.layoutManager?.ensureLayout(for: nsView.textContainer!)
        let rect = nsView.layoutManager?.usedRect(for: nsView.textContainer!) ?? .zero
        return CGSize(width: width, height: rect.height)
    }
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
