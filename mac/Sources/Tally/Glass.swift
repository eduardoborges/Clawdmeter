import SwiftUI

// Liquid Glass on macOS 26 and later, kept to the control layer as Apple's
// guidelines ask: tabs and buttons float on glass, content stays on the
// project's flat surfaces. Older systems get the flat design. The system swaps
// glass for an opaque fill when Reduce Transparency is on.

extension View {
    /// A secondary action: glass on macOS 26, plain text before.
    @ViewBuilder func glassAction() -> some View {
        if #available(macOS 26, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.plain)
        }
    }

    /// The one primary action in a view: terracotta glass on macOS 26.
    @ViewBuilder func glassPrimaryAction() -> some View {
        if #available(macOS 26, *) {
            buttonStyle(.glassProminent).tint(Theme.accent)
        } else {
            buttonStyle(.borderedProminent).tint(Theme.accent)
        }
    }

    /// The panel's backdrop: the system's glass tinted toward the display's
    /// surface color, or that color itself before macOS 26.
    @ViewBuilder func panelBackground() -> some View {
        if #available(macOS 26, *) {
            background(Theme.background.opacity(0.5)).background(Color.clear.glassEffect(.regular, in: .rect))
        } else {
            background(Theme.background)
        }
    }
}

/// Two tabs. On macOS 26 the selection is a terracotta glass capsule that
/// slides between them; before, an underline.
struct GlassTabs<Tab: Hashable & RawRepresentable>: View where Tab.RawValue == String {
    let tabs: [Tab]
    @Binding var selection: Tab
    @Namespace private var glass

    var body: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 4) {
                    ForEach(tabs, id: \.self) { tab in
                        Button { withAnimation(.smooth(duration: 0.3)) { selection = tab } } label: {
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 14).padding(.vertical, 5)
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(selection == tab ? Theme.text : Theme.dim)
                        .glassEffect(selection == tab ? .regular.tint(Theme.accent.opacity(0.45)).interactive() : .identity,
                                     in: .capsule)
                        .glassEffectID(tab, in: glass)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: 16) {
                ForEach(tabs, id: \.self) { tab in
                    Button { selection = tab } label: {
                        VStack(spacing: 4) {
                            Text(tab.rawValue).font(.system(size: 12, weight: .medium))
                                .foregroundStyle(selection == tab ? Theme.text : Theme.faint)
                            Rectangle().fill(selection == tab ? Theme.accent : .clear).frame(height: 2)
                        }
                        .fixedSize()
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
        }
    }
}
