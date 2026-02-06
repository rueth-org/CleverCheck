import SwiftUI
import UIKit

/// A lightweight UIViewRepresentable that reports tap locations inside its bounds
/// without interfering with parent pan/swipe gestures (uses UITapGestureRecognizer).
struct TapLocationView: UIViewRepresentable {
    var onTapLocation: (CGPoint) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        // Allow simultaneous recognition with other gestures (like pan/swipe)
        tap.cancelsTouchesInView = false
        tap.delegate = context.coordinator
        view.addGestureRecognizer(tap)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // nothing to update
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTapLocation: onTapLocation)
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let onTapLocation: (CGPoint) -> Void

        init(onTapLocation: @escaping (CGPoint) -> Void) {
            self.onTapLocation = onTapLocation
        }

        @objc func tapped(_ sender: UITapGestureRecognizer) {
            // Report coordinates relative to the tap view's bounds so SwiftUI can use them
            // directly when the TapLocationView is positioned/sized to the chart plot area.
            let loc = sender.location(in: sender.view)
            onTapLocation(loc)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Allow the tap recognizer to recognize simultaneously with other gestures
            return true
        }
    }
}
