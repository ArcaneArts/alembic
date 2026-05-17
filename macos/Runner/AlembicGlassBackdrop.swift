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
        if NSClassFromString("NSGlassEffectView") != nil {
            return .liquidGlass
        }
        return .vibrancy
    }
}

final class AlembicGlassBackdrop: NSView {
    private(set) var material: AlembicMaterial
    private(set) var cornerRadius: CGFloat
    private weak var glassEffectView: NSView?
    private weak var vibrancyView: NSVisualEffectView?
    private weak var solidLayer: CALayer?

    init(frame: NSRect, cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
        self.material = AlembicMaterial.detect()
        super.init(frame: frame)
        self.wantsLayer = true
        self.autoresizingMask = [.width, .height]
        self.layer?.cornerRadius = cornerRadius
        self.layer?.masksToBounds = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
        installMaterialView()
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

    func refresh() {
        layer?.setNeedsDisplay()
    }

    func setCornerRadius(_ radius: CGFloat) {
        guard radius != cornerRadius else {
            return
        }
        cornerRadius = radius
        layer?.cornerRadius = radius
        glassEffectView?.layer?.cornerRadius = radius
        if let glass: NSView = glassEffectView,
           glass.responds(to: NSSelectorFromString("setCornerRadius:")) {
            glass.setValue(radius, forKey: "cornerRadius")
        }
        vibrancyView?.layer?.cornerRadius = radius
        solidLayer?.cornerRadius = radius
    }

    func setMaterial(_ next: AlembicMaterial) {
        guard next != material else {
            return
        }
        material = next
        glassEffectView?.removeFromSuperview()
        vibrancyView?.removeFromSuperview()
        glassEffectView = nil
        vibrancyView = nil
        solidLayer?.removeFromSuperlayer()
        solidLayer = nil
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
                installVibrancy()
            }
        case .vibrancy:
            installVibrancy()
        case .solid:
            installSolid()
        }
    }

    private func installLiquidGlass() -> Bool {
        guard let glassClass: NSView.Type = NSClassFromString("NSGlassEffectView") as? NSView.Type else {
            return false
        }
        let glass: NSView = glassClass.init(frame: bounds)
        glass.autoresizingMask = [.width, .height]
        glass.wantsLayer = true
        glass.layer?.cornerRadius = cornerRadius
        glass.layer?.masksToBounds = true
        if glass.responds(to: NSSelectorFromString("setCornerRadius:")) {
            glass.setValue(cornerRadius, forKey: "cornerRadius")
        }
        addSubview(glass, positioned: .below, relativeTo: nil)
        glassEffectView = glass
        return true
    }

    private func installVibrancy() {
        let view: NSVisualEffectView = NSVisualEffectView(frame: bounds)
        view.autoresizingMask = [.width, .height]
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = false
        view.appearance = NSAppearance(named: .aqua)
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.masksToBounds = true
        view.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.10).cgColor
        addSubview(view, positioned: .below, relativeTo: nil)
        vibrancyView = view
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
