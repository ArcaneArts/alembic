import SwiftUI
import AppKit

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
        case .window: return 0.22
        case .toolbar: return 0.10
        case .panel: return 0.10
        case .card: return 0.08
        case .metric: return 0.08
        case .control: return 0.06
        case .row: return 0.03
        case .sidebar: return 0.08
        case .sheet: return 0.18
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .window: return 32
        case .toolbar: return 14
        case .panel: return 24
        case .card: return 18
        case .metric: return 18
        case .control: return 10
        case .row: return 6
        case .sidebar: return 16
        case .sheet: return 30
        }
    }

    @available(macOS 26.0, *)
    var glass: Glass {
        switch self {
        case .control, .row:
            return Glass.clear.interactive().tint(Color.white.opacity(0.045))
        default:
            return Glass.clear.tint(Color.white.opacity(0.045))
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
        if #available(macOS 26.0, *), !reduceTransparency {
            AlembicLiquidGlassSurface(style: style, padding: padding, content: content)
        } else {
            fallbackSurface
        }
    }

    private var fallbackSurface: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                    .fill(fallbackStyle)
            )
            .overlay(
                RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: AlembicGlassTokens.hairline)
            )
            .shadow(
                color: Color.black.opacity(style.shadowOpacity),
                radius: style.shadowRadius,
                x: 0,
                y: style.shadowRadius / 3
            )
    }

    private var fallbackStyle: AnyShapeStyle {
        if reduceTransparency {
            return AnyShapeStyle(Color(nsColor: .windowBackgroundColor).opacity(colorScheme == .dark ? 0.92 : 0.86))
        }
        return AnyShapeStyle(.ultraThinMaterial)
    }

    private var borderColor: Color {
        return Color.white.opacity(colorScheme == .dark ? style.strokeOpacity : style.strokeOpacity + 0.10)
    }
}

@available(macOS 26.0, *)
private struct AlembicLiquidGlassSurface<Content: View>: View {
    let style: AlembicGlassSurfaceStyle
    let padding: EdgeInsets
    @ViewBuilder var content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            content()
                .padding(padding)
                .background(
                    RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                        .fill(Color.white.opacity(colorScheme == .dark ? style.fillOpacity : style.fillOpacity + 0.018))
                )
                .glassEffect(
                    style.glass,
                    in: RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: AlembicGlassTokens.hairline)
                )
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.46 : 0.64),
                                    Color.white.opacity(colorScheme == .dark ? 0.10 : 0.18),
                                    Color.accentColor.opacity(0.10),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.9
                        )
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.black.opacity(colorScheme == .dark ? 0.20 : 0.08),
                                    Color.accentColor.opacity(0.12),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.7
                        )
                        .allowsHitTesting(false)
                }
                .shadow(
                    color: Color.black.opacity(style.shadowOpacity),
                    radius: style.shadowRadius,
                    x: 0,
                    y: style.shadowRadius / 3
                )
        }
    }

    private var borderColor: Color {
        return Color.white.opacity(colorScheme == .dark ? style.strokeOpacity : style.strokeOpacity + 0.12)
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
