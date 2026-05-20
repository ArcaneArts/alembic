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
    private weak var glassContainerView: NSView?
    private weak var glassEffectView: NSView?
    private weak var vibrancyView: NSVisualEffectView?
    private weak var solidLayer: CALayer?
    private weak var gradientLayer: CAGradientLayer?
    private var appearanceObservation: NSObjectProtocol?

    init(frame: NSRect, cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
        self.material = AlembicMaterial.detect()
        super.init(frame: frame)
        self.wantsLayer = true
        self.autoresizingMask = [.width, .height]
        self.layer?.backgroundColor = NSColor.clear.cgColor
        installMaterialView()
        startObservingAppearance()
        os_log(
            "AlembicGlassBackdrop init: material=%{public}@ cornerRadius=%.1f",
            log: .alembicBackdrop,
            type: .info,
            material.rawValue,
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
        layer?.setNeedsDisplay()
    }

    func setCornerRadius(_ radius: CGFloat) {
        guard radius != cornerRadius else {
            return
        }
        cornerRadius = radius
        if #available(macOS 26.0, *),
           let glass: NSGlassEffectView = glassEffectView as? NSGlassEffectView {
            glass.cornerRadius = radius
        }
    }

    func setMaterial(_ next: AlembicMaterial) {
        guard next != material else {
            return
        }
        material = next
        glassContainerView?.removeFromSuperview()
        glassEffectView?.removeFromSuperview()
        vibrancyView?.removeFromSuperview()
        glassContainerView = nil
        glassEffectView = nil
        vibrancyView = nil
        solidLayer?.removeFromSuperlayer()
        solidLayer = nil
        gradientLayer?.removeFromSuperlayer()
        gradientLayer = nil
        installMaterialView()
        os_log(
            "AlembicGlassBackdrop setMaterial: -> %{public}@",
            log: .alembicBackdrop,
            type: .info,
            next.rawValue
        )
    }

    private func installMaterialView() {
        switch material {
        case .liquidGlass:
            if !installLiquidGlass() {
                material = .vibrancy
                installFauxGlass()
            }
        case .vibrancy:
            installFauxGlass()
        case .solid:
            installSolid()
        }
    }

    private func installLiquidGlass() -> Bool {
        guard #available(macOS 26.0, *) else {
            return false
        }
        let container: NSGlassEffectContainerView = NSGlassEffectContainerView(frame: bounds)
        container.autoresizingMask = [.width, .height]
        container.spacing = 10
        container.wantsLayer = true

        let glass: NSGlassEffectView = NSGlassEffectView(frame: bounds)
        glass.autoresizingMask = [.width, .height]
        glass.style = .regular
        glass.cornerRadius = cornerRadius
        glass.tintColor = NSColor.controlAccentColor.withAlphaComponent(0.05)
        glass.wantsLayer = true
        container.contentView = glass
        addSubview(container, positioned: .below, relativeTo: nil)
        glassContainerView = container
        glassEffectView = glass
        return true
    }

    private func installFauxGlass() {
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
                NSColor(white: 0.04, alpha: 0.88).cgColor,
                NSColor(white: 0.02, alpha: 0.90).cgColor,
                NSColor(white: 0.01, alpha: 0.86).cgColor,
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

    private func installSolid() {
        let solid: CALayer = CALayer()
        solid.frame = bounds
        solid.cornerRadius = cornerRadius
        solid.masksToBounds = true
        solid.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.92).cgColor
        solid.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer?.insertSublayer(solid, at: 0)
        solidLayer = solid
    }
}
