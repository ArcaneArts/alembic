import SwiftUI
import AppKit

enum AlembicThemePreference: String, CaseIterable {
    case light
    case dark
    case system

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
}

final class AlembicGlassLegibilityController: ObservableObject {
    static let shared: AlembicGlassLegibilityController = AlembicGlassLegibilityController()
    static let preferenceDefaultsKey: String = "alembic.theme.preference"
    static let themeChangedNotification: Notification.Name = Notification.Name("alembic.theme.changed")

    @Published private(set) var colorScheme: ColorScheme
    @Published private(set) var backdropLuminance: Double
    @Published private(set) var preference: AlembicThemePreference
    private var appearanceObservation: NSKeyValueObservation?

    private init() {
        let stored: String = UserDefaults.standard.string(forKey: AlembicGlassLegibilityController.preferenceDefaultsKey) ?? AlembicThemePreference.light.rawValue
        let pref: AlembicThemePreference = AlembicThemePreference(rawValue: stored) ?? .light
        self.preference = pref
        let initialScheme: ColorScheme = AlembicGlassLegibilityController.resolveColorScheme(for: pref)
        self.colorScheme = initialScheme
        self.backdropLuminance = initialScheme == .dark ? 0.20 : 0.80
        startObservingAppearance()
    }

    deinit {
        appearanceObservation?.invalidate()
    }

    func setPreference(_ next: AlembicThemePreference) {
        guard next != preference else {
            return
        }
        preference = next
        UserDefaults.standard.set(next.rawValue, forKey: AlembicGlassLegibilityController.preferenceDefaultsKey)
        applyPreference()
        NotificationCenter.default.post(name: AlembicGlassLegibilityController.themeChangedNotification, object: nil)
    }

    func refresh() {
        applyPreference()
    }

    func prepareForWindowOpen(_ window: NSWindow, completion: @escaping () -> Void) {
        applyPreference()
        completion()
    }

    private func startObservingAppearance() {
        appearanceObservation = NSApp.observe(
            \.effectiveAppearance,
            options: [.new]
        ) { [weak self] _, _ in
            DispatchQueue.main.async {
                guard let self: AlembicGlassLegibilityController = self,
                      self.preference == .system else {
                    return
                }
                self.applyPreference()
            }
        }
    }

    private func applyPreference() {
        let nextColorScheme: ColorScheme = AlembicGlassLegibilityController.resolveColorScheme(for: preference)
        let nextLuminance: Double = nextColorScheme == .dark ? 0.20 : 0.80
        if colorScheme != nextColorScheme {
            colorScheme = nextColorScheme
        }
        if abs(backdropLuminance - nextLuminance) > 0.01 {
            backdropLuminance = nextLuminance
        }
    }

    private static func resolveColorScheme(for preference: AlembicThemePreference) -> ColorScheme {
        switch preference {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return systemColorScheme
        }
    }

    private static var systemColorScheme: ColorScheme {
        let appearance: NSAppearance = NSApplication.shared.effectiveAppearance
        let match: NSAppearance.Name? = appearance.bestMatch(from: [.aqua, .darkAqua])
        return match == .darkAqua ? .dark : .light
    }
}

enum AlembicGlassSurfaceStyle {
    case window
    case toolbar
    case panel
    case card
    case metric
    case control
    case row
    case sidebar
    case sheet

    var cornerRadius: CGFloat {
        switch self {
        case .window: return 22
        case .toolbar: return 15
        case .panel: return 16
        case .card: return 14
        case .metric: return 14
        case .control: return 10
        case .row: return 11
        case .sidebar: return 18
        case .sheet: return 22
        }
    }

    var strokeOpacity: Double {
        switch self {
        case .window: return 0.24
        case .toolbar: return 0.34
        case .panel: return 0.32
        case .card: return 0.30
        case .metric: return 0.34
        case .control: return 0.28
        case .row: return 0.18
        case .sidebar: return 0.28
        case .sheet: return 0.34
        }
    }

    var shadowOpacity: Double {
        switch self {
        case .window: return 0.18
        case .toolbar: return 0.0
        case .panel: return 0.0
        case .card: return 0.0
        case .metric: return 0.0
        case .control: return 0.0
        case .row: return 0.0
        case .sidebar: return 0.0
        case .sheet: return 0.16
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .window: return 14
        case .toolbar: return 0
        case .panel: return 0
        case .card: return 0
        case .metric: return 0
        case .control: return 0
        case .row: return 0
        case .sidebar: return 0
        case .sheet: return 14
        }
    }

    var fillOpacity: Double {
        switch self {
        case .toolbar: return 0.020
        case .panel: return 0.020
        case .card: return 0.020
        case .metric: return 0.018
        case .control: return 0.018
        case .row: return 0.012
        case .sidebar: return 0.020
        case .sheet: return 0.020
        case .window: return 0.0
        }
    }

    var backgroundMaterial: Material? {
        return nil
    }

    var edgeHighlightStrength: Double {
        switch self {
        case .window: return 0.0
        case .toolbar: return 0.95
        case .panel: return 0.85
        case .card: return 0.82
        case .metric: return 0.80
        case .control: return 0.75
        case .row: return 0.55
        case .sidebar: return 0.85
        case .sheet: return 1.00
        }
    }

    var usesGlassEffect: Bool {
        switch self {
        case .row, .control:
            return false
        default:
            return true
        }
    }

    @available(macOS 26.0, *)
    func glass(tintOpacity: Double, colorScheme: ColorScheme) -> Glass {
        let tintColor: Color = colorScheme == .dark
            ? Color.black.opacity(tintOpacity)
            : Color.white.opacity(tintOpacity)
        return Glass.clear.tint(tintColor)
    }

    func glassTintOpacity(colorScheme: ColorScheme, luminance: Double) -> Double {
        if colorScheme == .light {
            return 0.45
        }
        return 0.40
    }

    func legibilityFillOpacity(colorScheme: ColorScheme, luminance: Double) -> Double {
        let clampedLuminance: Double = min(1.0, max(0.0, luminance))
        if colorScheme == .light {
            let brightBoost: Double = max(0.0, clampedLuminance - 0.48) * 0.54
            return min(lightLegibilityMaxOpacity, lightLegibilityBaseOpacity + brightBoost)
        }
        let darkBoost: Double = max(0.0, 0.52 - clampedLuminance) * 0.34
        return min(darkLegibilityMaxOpacity, darkLegibilityBaseOpacity + darkBoost)
    }

    private var lightLegibilityBaseOpacity: Double {
        switch self {
        case .window: return 0.0
        case .toolbar: return 0.0
        case .panel: return 0.0
        case .card: return 0.0
        case .metric: return 0.0
        case .control: return 0.40
        case .row: return 0.30
        case .sidebar: return 0.0
        case .sheet: return 0.0
        }
    }

    private var lightLegibilityMaxOpacity: Double {
        switch self {
        case .window: return 0.0
        case .toolbar: return 0.0
        case .panel: return 0.0
        case .card: return 0.0
        case .metric: return 0.0
        case .control: return 0.50
        case .row: return 0.42
        case .sidebar: return 0.0
        case .sheet: return 0.0
        }
    }

    private var darkLegibilityBaseOpacity: Double {
        switch self {
        case .window: return 0.0
        case .toolbar: return 0.0
        case .panel: return 0.0
        case .card: return 0.0
        case .metric: return 0.0
        case .control: return 0.55
        case .row: return 0.42
        case .sidebar: return 0.0
        case .sheet: return 0.0
        }
    }

    private var darkLegibilityMaxOpacity: Double {
        switch self {
        case .window: return 0.0
        case .toolbar: return 0.0
        case .panel: return 0.0
        case .card: return 0.0
        case .metric: return 0.0
        case .control: return 0.65
        case .row: return 0.55
        case .sidebar: return 0.0
        case .sheet: return 0.0
        }
    }
}

enum AlembicGlassTokens {
    static let appPadding: CGFloat = 12
    static let panelSpacing: CGFloat = 10
    static let hairline: CGFloat = 0.75
    static let rowHeight: CGFloat = 58
    static let commandHeight: CGFloat = 44
    static let metricMinWidth: CGFloat = 142

    static func defaultPadding(for style: AlembicGlassSurfaceStyle) -> EdgeInsets {
        switch style {
        case .toolbar:
            return EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
        case .panel:
            return EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        case .card:
            return EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        case .metric:
            return EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        case .control:
            return EdgeInsets(top: 7, leading: 11, bottom: 7, trailing: 11)
        case .row:
            return EdgeInsets(top: 9, leading: 12, bottom: 9, trailing: 12)
        case .sidebar:
            return EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        case .sheet:
            return EdgeInsets(top: 22, leading: 22, bottom: 22, trailing: 22)
        case .window:
            return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        }
    }
}

struct AlembicDashboardMetric: Identifiable, Hashable {
    let id: String
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let tint: Color
}

struct AlembicGlassSurface<Content: View>: View {
    let style: AlembicGlassSurfaceStyle
    let padding: EdgeInsets
    @ViewBuilder var content: () -> Content

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var legibility: AlembicGlassLegibilityController = AlembicGlassLegibilityController.shared

    init(
        style: AlembicGlassSurfaceStyle = .panel,
        padding: EdgeInsets? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.style = style
        self.padding = padding ?? AlembicGlassTokens.defaultPadding(for: style)
        self.content = content
    }

    var body: some View {
        if #available(macOS 26.0, *), !reduceTransparency, style.usesGlassEffect {
            liquidGlassBody
        } else {
            fallbackBody
        }
    }

    @available(macOS 26.0, *)
    private var liquidGlassBody: some View {
        content()
            .padding(padding)
            .glassEffect(
                style.glass(tintOpacity: glassTintOpacity, colorScheme: colorScheme),
                in: RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
            )
            .overlay(borderStroke)
            .modifier(AlembicGlassShadow(style: style))
    }

    private var fallbackBody: some View {
        content()
            .padding(padding)
            .background(backgroundLayer)
            .overlay(borderStroke)
            .modifier(AlembicGlassShadow(style: style))
    }

    private var glassTintOpacity: Double {
        return style.glassTintOpacity(colorScheme: colorScheme, luminance: legibility.backdropLuminance)
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        let shape: RoundedRectangle = RoundedRectangle(
            cornerRadius: style.cornerRadius,
            style: .continuous
        )
        if reduceTransparency {
            shape
                .fill(legibilityFillColor.opacity(max(0.86, legibilityFillOpacity)))
                .allowsHitTesting(false)
        } else if let material: Material = style.backgroundMaterial {
            ZStack {
                shape.fill(material)
                shape.fill(tintFillColor.opacity(tintFillOpacity))
            }
            .allowsHitTesting(false)
        } else {
            shape
                .fill(legibilityFillColor.opacity(legibilityFillOpacity))
                .allowsHitTesting(false)
        }
    }

    private var borderStroke: some View {
        RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
            .strokeBorder(borderColor, lineWidth: AlembicGlassTokens.hairline)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var edgeHighlight: some View {
        if !reduceTransparency, style.edgeHighlightStrength > 0 {
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        stops: [
                            Gradient.Stop(color: Color.white.opacity(highlightTopOpacity), location: 0.0),
                            Gradient.Stop(color: Color.white.opacity(highlightMidOpacity), location: 0.45),
                            Gradient.Stop(color: Color.white.opacity(0.0), location: 0.85),
                            Gradient.Stop(color: Color.white.opacity(highlightTrailingOpacity), location: 1.0),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.4
                )
                .blendMode(colorScheme == .dark ? .plusLighter : .normal)
                .allowsHitTesting(false)
        }
    }

    private var highlightTopOpacity: Double {
        let base: Double = style.edgeHighlightStrength
        return colorScheme == .dark ? base * 0.85 : base * 0.95
    }

    private var highlightMidOpacity: Double {
        let base: Double = style.edgeHighlightStrength
        return colorScheme == .dark ? base * 0.20 : base * 0.30
    }

    private var highlightTrailingOpacity: Double {
        let base: Double = style.edgeHighlightStrength
        return colorScheme == .dark ? base * 0.18 : base * 0.10
    }

    private var tintFillColor: Color {
        return colorScheme == .dark ? Color.white : Color.white
    }

    private var tintFillOpacity: Double {
        let base: Double = style.fillOpacity
        return colorScheme == .dark ? base * 1.4 : base * 1.8
    }

    private var borderColor: Color {
        return Color.primary.opacity(colorScheme == .dark ? style.strokeOpacity * 0.5 : style.strokeOpacity * 0.4)
    }

    private var legibilityFillColor: Color {
        return colorScheme == .dark ? Color.black : Color.white
    }

    private var legibilityFillOpacity: Double {
        return style.legibilityFillOpacity(colorScheme: colorScheme, luminance: legibility.backdropLuminance)
    }
}

private struct AlembicGlassShadow: ViewModifier {
    let style: AlembicGlassSurfaceStyle

    func body(content: Content) -> some View {
        if style.shadowRadius > 0 && style.shadowOpacity > 0 {
            content.shadow(
                color: Color.black.opacity(style.shadowOpacity),
                radius: style.shadowRadius,
                x: 0,
                y: style.shadowRadius / 3
            )
        } else {
            content
        }
    }
}

extension View {
    func alembicGlassSurface(
        _ style: AlembicGlassSurfaceStyle = .panel,
        padding: EdgeInsets? = nil
    ) -> some View {
        AlembicGlassSurface(style: style, padding: padding) {
            self
        }
    }
}

struct AlembicGlassIconButton: View {
    let systemImage: String
    let help: String
    let isActive: Bool
    let action: () -> Void

    init(
        systemImage: String,
        help: String,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.help = help
        self.isActive = isActive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isActive ? Color.accentColor : Color.primary.opacity(0.78))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .alembicGlassSurface(
            .control,
            padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        )
        .help(help)
    }
}
