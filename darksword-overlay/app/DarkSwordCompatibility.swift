import SwiftUI

/// Back-port of SwiftUI's iOS 17 two-value `onChange` overload.
///
/// The modifier stores the last delivered value and preserves the newer
/// `(oldValue, newValue)` closure semantics on iOS 16. The one-value overload
/// delegates to SwiftUI's native iOS 14+ implementation.
private struct DarkSwordTwoValueOnChangeModifier<Value: Equatable>: ViewModifier {
    let value: Value
    let initial: Bool
    let action: (Value, Value) -> Void

    @State private var previousValue: Value?
    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true
                previousValue = value
                if initial {
                    action(value, value)
                }
            }
            .onChange(of: value) { nextValue in
                let oldValue = previousValue ?? nextValue
                previousValue = nextValue
                action(oldValue, nextValue)
            }
    }
}

extension View {
    func darkswordOnChange<Value: Equatable>(
        of value: Value,
        perform action: @escaping (Value) -> Void
    ) -> some View {
        onChange(of: value, perform: action)
    }

    func darkswordOnChange<Value: Equatable>(
        of value: Value,
        initial: Bool = false,
        _ action: @escaping (Value, Value) -> Void
    ) -> some View {
        modifier(
            DarkSwordTwoValueOnChangeModifier(
                value: value,
                initial: initial,
                action: action
            )
        )
    }

    func darkswordOnChange<Value: Equatable>(
        of value: Value,
        initial: Bool = false,
        _ action: @escaping () -> Void
    ) -> some View {
        darkswordOnChange(of: value, initial: initial) { _, _ in action() }
    }
}

/// iOS 16 replacement for the common iOS 17 `ContentUnavailableView` shape
/// used by DarkSword and upstream Litter empty states.
struct DarkSwordContentUnavailableView<Description: View>: View {
    let title: String
    let systemImage: String
    let description: () -> Description

    init(
        _ title: String,
        systemImage: String,
        @ViewBuilder description: @escaping () -> Description
    ) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
    }

    init(
        _ title: String,
        systemImage: String,
        description: Description
    ) {
        self.title = title
        self.systemImage = systemImage
        self.description = { description }
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            description()
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 420)
        .padding(24)
        .accessibilityElement(children: .combine)
    }
}

extension DarkSwordContentUnavailableView where Description == EmptyView {
    init(_ title: String, systemImage: String) {
        self.init(title, systemImage: systemImage) { EmptyView() }
    }
}
