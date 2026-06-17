import SwiftUI
import VisionKit

/// Live barcode scanner (VisionKit DataScanner). Calls `onScan` with the first
/// barcode payload. Falls back to a message where the scanner is unavailable
/// (e.g. the simulator, which has no camera).
struct BarcodeScannerView: View {
    var onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LivaBackground()
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    BarcodeScannerRepresentable { code in onScan(code); dismiss() }
                        .ignoresSafeArea()
                    VStack {
                        Spacer()
                        Text("Point at a barcode")
                            .font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(Capsule().fill(.black.opacity(0.5)))
                            .padding(.bottom, 40)
                    }
                } else {
                    EmptyStateView(systemName: "barcode.viewfinder",
                                   title: "Camera not available",
                                   message: "Barcode scanning needs a device with a camera. Try search or describe instead.")
                }
            }
            .navigationTitle("Scan Barcode").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.foregroundStyle(Theme.Palette.ink) } }
        }
    }
}

private struct BarcodeScannerRepresentable: UIViewControllerRepresentable {
    var onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        private var handled = false
        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            handle(addedItems)
        }
        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            handle([item])
        }
        private func handle(_ items: [RecognizedItem]) {
            guard !handled else { return }
            for item in items {
                if case let .barcode(barcode) = item, let payload = barcode.payloadStringValue {
                    handled = true
                    onScan(payload)
                    return
                }
            }
        }
    }
}
