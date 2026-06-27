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

enum AlembicGlassIntensity: String, CaseIterable {
    case subtle
    case balanced
    case vivid

    var displayName: String {
        switch self {
        case .subtle: return "Subtle"
        case .balanced: return "Balanced"
        case .vivid: return "Vivid"
        }
    }

    var tintScale: Double {
        switch self {
        case .subtle: return 0.78
        case .balanced: return 1.00
        case .vivid: return 1.18
        }
    }

    var fillDelta: Double {
        switch self {
        case .subtle: return -0.055
        case .balanced: return 0.0
        case .vivid: return 0.045
        }
    }

    var highlightScale: Double {
        switch self {
        case .subtle: return 0.64
        case .balanced: return 1.00
        case .vivid: return 1.26
        }
    }

    var backdropScale: CGFloat {
        switch self {
        case .subtle: return 0.78
        case .balanced: return 1.00
        case .vivid: return 1.16
        }
    }
}

final class AlembicGlassLegibilityController: ObservableObject {
    static let shared: AlembicGlassLegibilityController = AlembicGlassLegibilityController()
    static let preferenceDefaultsKey: String = "alembic.theme.preference"
    static let glassEnabledDefaultsKey: String = "alembic.glass.enabled"
    static let glassIntensityDefaultsKey: String = "alembic.glass.intensity"
    static let themeChangedNotification: Notification.Name = Notification.Name("alembic.theme.changed")

    @Published private(set) var colorScheme: ColorScheme
    @Published private(set) var preference: AlembicThemePreference
    @Published private(set) var glassEnabled: Bool
    @Published private(set) var glassIntensity: AlembicGlassIntensity
    private var appearanceObservation: NSKeyValueObservation?

    private init() {
        let stored: String = UserDefaults.standard.string(forKey: AlembicGlassLegibilityController.preferenceDefaultsKey) ?? AlembicThemePreference.light.rawValue
        let pref: AlembicThemePreference = AlembicThemePreference(rawValue: stored) ?? .light
        let storedIntensity: String = UserDefaults.standard.string(forKey: AlembicGlassLegibilityController.glassIntensityDefaultsKey) ?? AlembicGlassIntensity.balanced.rawValue
        let intensity: AlembicGlassIntensity = AlembicGlassIntensity(rawValue: storedIntensity) ?? .balanced
        self.preference = pref
        self.glassIntensity = intensity
        if UserDefaults.standard.object(forKey: AlembicGlassLegibilityController.glassEnabledDefaultsKey) == nil {
            self.glassEnabled = true
        } else {
            self.glassEnabled = UserDefaults.standard.bool(forKey: AlembicGlassLegibilityController.glassEnabledDefaultsKey)
        }
        self.colorScheme = AlembicGlassLegibilityController.resolveColorScheme(for: pref)
        startObservingAppearance()
    }

    func setGlassEnabled(_ enabled: Bool) {
        guard enabled != glassEnabled else {
            return
        }
        glassEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: AlembicGlassLegibilityController.glassEnabledDefaultsKey)
        NotificationCenter.default.post(name: AlembicGlassLegibilityController.themeChangedNotification, object: nil)
    }

    func setGlassIntensity(_ next: AlembicGlassIntensity) {
        guard next != glassIntensity else {
            return
        }
        glassIntensity = next
        UserDefaults.standard.set(next.rawValue, forKey: AlembicGlassLegibilityController.glassIntensityDefaultsKey)
        NotificationCenter.default.post(name: AlembicGlassLegibilityController.themeChangedNotification, object: nil)
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
        if colorScheme != nextColorScheme {
            colorScheme = nextColorScheme
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

    func glassTintOpacity(colorScheme: ColorScheme, intensity: AlembicGlassIntensity) -> Double {
        let base: Double
        if colorScheme == .dark {
            switch self {
            case .window: base = 0.0
            case .toolbar: base = 0.54
            case .panel: base = 0.64
            case .card: base = 0.58
            case .metric: base = 0.54
            case .control: base = 0.36
            case .row: base = 0.28
            case .sidebar: base = 0.62
            case .sheet: base = 0.70
            }
        } else {
            switch self {
            case .window: base = 0.0
            case .toolbar: base = 0.32
            case .panel: base = 0.42
            case .card: base = 0.36
            case .metric: base = 0.34
            case .control: base = 0.24
            case .row: base = 0.18
            case .sidebar: base = 0.42
            case .sheet: base = 0.50
            }
        }
        return min(0.88, max(0.10, base * intensity.tintScale))
    }

    func legibilityFillOpacity(colorScheme: ColorScheme, intensity: AlembicGlassIntensity) -> Double {
        if colorScheme == .light {
            return min(lightLegibilityMaxOpacity, max(0.0, lightLegibilityBaseOpacity + 0.1728 + intensity.fillDelta))
        }
        return min(darkLegibilityMaxOpacity, max(0.0, darkLegibilityBaseOpacity + 0.1088 + intensity.fillDelta))
    }

    func liquidFillOpacity(colorScheme: ColorScheme, intensity: AlembicGlassIntensity) -> Double {
        let base: Double
        if colorScheme == .dark {
            switch self {
            case .window: base = 0.0
            case .toolbar: base = 0.12
            case .panel: base = 0.18
            case .card: base = 0.15
            case .metric: base = 0.13
            case .control: base = 0.08
            case .row: base = 0.08
            case .sidebar: base = 0.17
            case .sheet: base = 0.23
            }
        } else {
            switch self {
            case .window: base = 0.0
            case .toolbar: base = 0.10
            case .panel: base = 0.16
            case .card: base = 0.12
            case .metric: base = 0.10
            case .control: base = 0.06
            case .row: base = 0.06
            case .sidebar: base = 0.14
            case .sheet: base = 0.20
            }
        }
        return min(0.34, max(0.0, base + intensity.fillDelta * 0.55))
    }

    func effectiveEdgeHighlightStrength(intensity: AlembicGlassIntensity) -> Double {
        return min(1.0, edgeHighlightStrength * intensity.highlightScale)
    }

    private var lightLegibilityBaseOpacity: Double {
        switch self {
        case .window: return 0.0
        case .toolbar: return 0.55
        case .panel: return 0.62
        case .card: return 0.58
        case .metric: return 0.52
        case .control: return 0.20
        case .row: return 0.20
        case .sidebar: return 0.58
        case .sheet: return 0.72
        }
    }

    private var lightLegibilityMaxOpacity: Double {
        switch self {
        case .window: return 0.0
        case .toolbar: return 0.72
        case .panel: return 0.80
        case .card: return 0.76
        case .metric: return 0.70
        case .control: return 0.20
        case .row: return 0.20
        case .sidebar: return 0.76
        case .sheet: return 0.88
        }
    }

    private var darkLegibilityBaseOpacity: Double {
        switch self {
        case .window: return 0.0
        case .toolbar: return 0.50
        case .panel: return 0.58
        case .card: return 0.52
        case .metric: return 0.48
        case .control: return 0.20
        case .row: return 0.20
        case .sidebar: return 0.54
        case .sheet: return 0.66
        }
    }

    private var darkLegibilityMaxOpacity: Double {
        switch self {
        case .window: return 0.0
        case .toolbar: return 0.66
        case .panel: return 0.74
        case .card: return 0.68
        case .metric: return 0.64
        case .control: return 0.20
        case .row: return 0.20
        case .sidebar: return 0.70
        case .sheet: return 0.82
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
        if #available(macOS 26.0, *), !reduceTransparency, style.usesGlassEffect, legibility.glassEnabled {
            liquidGlassBody
        } else {
            fallbackBody
        }
    }

    @available(macOS 26.0, *)
    private var liquidGlassBody: some View {
        content()
            .padding(padding)
            .background {
                liquidLegibilityLayer
                    .allowsHitTesting(false)
            }
            .glassEffect(
                style.glass(tintOpacity: glassTintOpacity, colorScheme: colorScheme),
                in: RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
            )
            .overlay {
                edgeHighlight
                    .allowsHitTesting(false)
            }
            .overlay {
                borderStroke
                    .allowsHitTesting(false)
            }
            .modifier(AlembicGlassShadow(style: style))
    }

    private var fallbackBody: some View {
        content()
            .padding(padding)
            .background {
                backgroundLayer
                    .allowsHitTesting(false)
            }
            .overlay {
                edgeHighlight
                    .allowsHitTesting(false)
            }
            .overlay {
                borderStroke
                    .allowsHitTesting(false)
            }
            .modifier(AlembicGlassShadow(style: style))
    }

    private var glassTintOpacity: Double {
        return style.glassTintOpacity(colorScheme: colorScheme, intensity: legibility.glassIntensity)
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
        } else if style.usesGlassEffect {
            shape
                .fill(frostedFallbackGradient)
                .allowsHitTesting(false)
        } else {
            shape
                .fill(legibilityFillColor.opacity(legibilityFillOpacity))
                .allowsHitTesting(false)
        }
    }

    private var liquidLegibilityLayer: some View {
        RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
            .fill(legibilityFillColor.opacity(liquidFillOpacity))
            .allowsHitTesting(false)
    }

    private var frostedFallbackGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color(white: 0.18).opacity(0.78),
                    Color(white: 0.12).opacity(0.82),
                    Color(white: 0.08).opacity(0.86),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: [
                Color.white.opacity(0.74),
                Color(white: 0.96).opacity(0.78),
                Color(white: 0.92).opacity(0.82),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var borderStroke: some View {
        RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
            .strokeBorder(borderColor, lineWidth: AlembicGlassTokens.hairline)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var edgeHighlight: some View {
        if !reduceTransparency, effectiveEdgeHighlightStrength > 0 {
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
        let base: Double = effectiveEdgeHighlightStrength
        return colorScheme == .dark ? base * 0.85 : base * 0.95
    }

    private var highlightMidOpacity: Double {
        let base: Double = effectiveEdgeHighlightStrength
        return colorScheme == .dark ? base * 0.20 : base * 0.30
    }

    private var highlightTrailingOpacity: Double {
        let base: Double = effectiveEdgeHighlightStrength
        return colorScheme == .dark ? base * 0.18 : base * 0.10
    }

    private var borderColor: Color {
        return Color.primary.opacity(colorScheme == .dark ? style.strokeOpacity * 0.5 : style.strokeOpacity * 0.4)
    }

    private var legibilityFillColor: Color {
        return colorScheme == .dark ? Color.black : Color.white
    }

    private var legibilityFillOpacity: Double {
        return style.legibilityFillOpacity(colorScheme: colorScheme, intensity: legibility.glassIntensity)
    }

    private var liquidFillOpacity: Double {
        return style.liquidFillOpacity(colorScheme: colorScheme, intensity: legibility.glassIntensity)
    }

    private var effectiveEdgeHighlightStrength: Double {
        return style.effectiveEdgeHighlightStrength(intensity: legibility.glassIntensity)
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
    @State private var isHovering: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var legibility: AlembicGlassLegibilityController = AlembicGlassLegibilityController.shared

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
        .background(controlFill)
        .overlay(controlStroke)
        .shadow(
            color: Color.black.opacity(isHovering || isActive ? controlShadowOpacity : 0),
            radius: isHovering || isActive ? 4 : 0,
            x: 0,
            y: 1
        )
        .scaleEffect(isHovering ? 1.025 : 1.0)
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
        .help(help)
    }

    private var controlFill: some View {
        RoundedRectangle(cornerRadius: AlembicGlassSurfaceStyle.control.cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: controlFillColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .allowsHitTesting(false)
    }

    private var controlStroke: some View {
        RoundedRectangle(cornerRadius: AlembicGlassSurfaceStyle.control.cornerRadius, style: .continuous)
            .strokeBorder(controlStrokeColor, lineWidth: AlembicGlassTokens.hairline)
            .allowsHitTesting(false)
    }

    private var controlFillColors: [Color] {
        let scale: Double = legibility.glassIntensity.tintScale
        if isActive {
            return [
                Color.accentColor.opacity(min(0.32, 0.18 * scale)),
                Color.accentColor.opacity(min(0.22, 0.10 * scale)),
            ]
        }
        let topOpacity: Double = min(0.20, (isHovering ? 0.13 : 0.07) * scale)
        let bottomOpacity: Double = min(0.16, (isHovering ? 0.08 : 0.045) * scale)
        if colorScheme == .dark {
            return [
                Color.white.opacity(topOpacity),
                Color.white.opacity(bottomOpacity),
            ]
        }
        return [
            Color.white.opacity(topOpacity + 0.10),
            Color.black.opacity(bottomOpacity * 0.42),
        ]
    }

    private var controlStrokeColor: Color {
        if isActive {
            return Color.accentColor.opacity(0.42)
        }
        return Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.12)
    }

    private var controlShadowOpacity: Double {
        return colorScheme == .dark ? 0.22 : 0.12
    }
}
