import Cocoa
import os.log

private extension OSLog {
    static let alembicBackdrop: OSLog = OSLog(
        subsystem: "art.arcane.alembic.backdrop",
        category: "material"
    )
}

enum AlembicMaterial: String {
    case liquidGlass
    case vibrancy
    case solid

    static func detect() -> AlembicMaterial {
        return .vibrancy
    }
}

final class AlembicGlassBackdrop: NSView {
    private(set) var material: AlembicMaterial
    private(set) var cornerRadius: CGFloat
    private weak var gradientLayer: CAGradientLayer?
    private var appearanceObservation: NSObjectProtocol?

    init(frame: NSRect, cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
        self.material = AlembicMaterial.detect()
        super.init(frame: frame)
        self.wantsLayer = true
        self.autoresizingMask = [.width, .height]
        self.layer?.backgroundColor = NSColor.clear.cgColor
        installBackdrop()
        startObservingAppearance()
        os_log(
            "AlembicGlassBackdrop init: cornerRadius=%.1f",
            log: .alembicBackdrop,
            type: .info,
            cornerRadius
        )
    }

    convenience override init(frame frameRect: NSRect) {
        self.init(frame: frameRect, cornerRadius: 14)
    }

    convenience init() {
        self.init(frame: NSRect(x: 0, y: 0, width: 1, height: 1), cornerRadius: 14)
    }

    required init?(coder: NSCoder) {
        fatalError("AlembicGlassBackdrop does not support init(coder:)")
    }

    deinit {
        if let token: NSObjectProtocol = appearanceObservation {
            NotificationCenter.default.removeObserver(token)
        }
    }

    func refresh() {
        if let gradient: CAGradientLayer = gradientLayer {
            applyGradientColors(gradient)
        }
    }

    func setCornerRadius(_ radius: CGFloat) {
        cornerRadius = radius
    }

    func setMaterial(_ next: AlembicMaterial) {
        material = next
    }

    private func installBackdrop() {
        let gradient: CAGradientLayer = CAGradientLayer()
        gradient.frame = bounds
        gradient.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        gradient.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradient.endPoint = CGPoint(x: 1.0, y: 1.0)
        applyGradientColors(gradient)
        layer?.insertSublayer(gradient, at: 0)
        gradientLayer = gradient
    }

    private func applyGradientColors(_ gradient: CAGradientLayer) {
        let isDark: Bool = AlembicGlassLegibilityController.shared.colorScheme == .dark
        if isDark {
            gradient.colors = [
                NSColor(white: 0.03, alpha: 1.0).cgColor,
                NSColor(white: 0.015, alpha: 1.0).cgColor,
                NSColor(white: 0.00, alpha: 1.0).cgColor,
            ]
        } else {
            gradient.colors = [
                NSColor(white: 0.96, alpha: 0.74).cgColor,
                NSColor(white: 0.92, alpha: 0.72).cgColor,
                NSColor(white: 0.88, alpha: 0.68).cgColor,
            ]
        }
        gradient.locations = [0.0, 0.50, 1.0]
    }

    private func startObservingAppearance() {
        appearanceObservation = NotificationCenter.default.addObserver(
            forName: AlembicGlassLegibilityController.themeChangedNotification,
            object: nil,
            queue: OperationQueue.main
        ) { [weak self] _ in
            guard let self: AlembicGlassBackdrop = self,
                  let gradient: CAGradientLayer = self.gradientLayer else {
                return
            }
            self.applyGradientColors(gradient)
        }
    }
}
