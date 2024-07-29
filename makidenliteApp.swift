import SwiftUI
import GoogleMobileAds
import AppTrackingTransparency

@main
struct DecimalCalculationApp: App {
    @StateObject private var viewModel = ContentViewModel()
    @State private var attStatus: ATTrackingManager.AuthorizationStatus = .notDetermined
    @State private var isATTAuthorized: Bool = false
    @State private var windowSize: CGSize = .zero

    init() {
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        isATTAuthorized = ATTrackingManager.trackingAuthorizationStatus == .authorized
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: viewModel,
                isATTAuthorized: $isATTAuthorized
            )
            .onAppear {
                checkAndRequestATTPermission()
            }
            .modifier(ConditionalFrameModifier(useCustomSize: isMacCatalyst))
        }
        .windowResizability(.contentSize)
    }
    
    struct ConditionalFrameModifier: ViewModifier {
        let useCustomSize: Bool

        func body(content: Content) -> some View {
            if useCustomSize {
                content
                    .frame(minWidth: 400, idealWidth: 500, maxWidth: 600,
                           minHeight: 600, idealHeight: 800, maxHeight: 1000)
            } else {
                content
            }
        }
    }

    
    private func checkAndRequestATTPermission() {
            attStatus = ATTrackingManager.trackingAuthorizationStatus
            
            switch attStatus {
            case .notDetermined:
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    ATTrackingManager.requestTrackingAuthorization { status in
                        DispatchQueue.main.async {
                            self.attStatus = status
                            self.isATTAuthorized = status == .authorized
                        }
                    }
                }
            case .restricted, .denied:
                isATTAuthorized = false
            case .authorized:
                isATTAuthorized = true
            @unknown default:
                isATTAuthorized = false
            }
    }
}


class DecimalCalculator {
    static let shared = DecimalCalculator()
    var result: Decimal = 0
    private init() {}  // privateイニシャライザを追加
    func add(_ a: Decimal, _ b: Decimal) {
        result = a + b
    }
    func subtract(_ a: Decimal, _ b: Decimal) {
        result = a - b
    }
    func multiply(_ a: Decimal, _ b: Decimal) {
        result = a * b
    }
    func divide(_ a: Decimal, _ b: Decimal) {
        guard b != 0 else {
            // 0での除算を防ぐ
            result = 0
            return
        }
        result = a / b
    }
    func formatResult() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 10
        return formatter.string(from: result as NSNumber) ?? "Error"
    }
}


let isMacCatalyst: Bool = {
    #if os(iOS)
        if #available(iOS 14.0, *) {
            return UIDevice.current.isRunningOnMac
        } else {
            return false
        }
    #else
        return false
    #endif
}()

private extension UIDevice {
    @available(iOS 14.0, *)
    var isRunningOnMac: Bool {
        return ProcessInfo.processInfo.isiOSAppOnMac || ProcessInfo.processInfo.isMacCatalystApp
    }
}
