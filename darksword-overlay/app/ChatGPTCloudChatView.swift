import SafariServices
import SwiftUI

/// Opens the official ChatGPT cloud product inside Apple's secure browser
/// controller. This route uses normal ChatGPT product usage and never sends
/// the conversation through AlleyCat's Codex runtime.
struct ChatGPTCloudChatView: UIViewControllerRepresentable {
    private let url = URL(string: "https://chatgpt.com/")!

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false
        configuration.barCollapsingEnabled = true

        let controller = SFSafariViewController(url: url, configuration: configuration)
        controller.dismissButtonStyle = .close
        controller.preferredControlTintColor = UIColor.tintColor
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}

    final class Coordinator: NSObject, SFSafariViewControllerDelegate {}
}
