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
        if #available(macOS 26.0, *) {
            return .liquidGlass
        }
        return .vibrancy
    }
}

final class AlembicGlassBackdrop: NSView {
    private(set) var material: AlembicMaterial
    private(set) var cornerRadius: CGFloat
    private weak var gradientLayer: CAGradientLayer?
    private var appearanceObservation: NSObjectProtocol?

    override var acceptsFirstResponder: Bool {
        return false
    }

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

    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
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
        if let gradient: CAGradientLayer = gradientLayer {
            applyGradientColors(gradient)
        }
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
        let intensityScale: CGFloat = AlembicGlassLegibilityController.shared.glassIntensity.backdropScale
        let materialScale: CGFloat = material == .liquidGlass ? 1.0 : 0.82
        let scale: CGFloat = intensityScale * materialScale
        if isDark {
            let topWhite: CGFloat = min(0.08, 0.045 * scale)
            let middleWhite: CGFloat = min(0.035, 0.018 * scale)
            gradient.colors = [
                NSColor(white: topWhite, alpha: 1.0).cgColor,
                NSColor(white: middleWhite, alpha: 1.0).cgColor,
                NSColor(white: 0.00, alpha: 1.0).cgColor,
            ]
        } else {
            let topAlpha: CGFloat = min(0.86, 0.70 + (scale * 0.05))
            let middleAlpha: CGFloat = min(0.84, 0.66 + (scale * 0.05))
            let bottomAlpha: CGFloat = min(0.82, 0.60 + (scale * 0.05))
            gradient.colors = [
                NSColor(white: 0.98, alpha: topAlpha).cgColor,
                NSColor(white: 0.93, alpha: middleAlpha).cgColor,
                NSColor(white: 0.86, alpha: bottomAlpha).cgColor,
            ]
        }
        gradient.locations = [0.0, 0.54, 1.0]
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
