import SwiftUI

public struct SimulatorControlBar: View {
    public let onRemainingMax: () -> Void
    public let onAllMax: () -> Void
    public let onReset: () -> Void
    public let onSavePlan: () -> Void
    public var isPlanSaved: Bool = false

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    onRemainingMax()
                } label: {
                    Label("Остаток на max", systemImage: "bolt.fill")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .tint(.orange)

                Button {
                    onAllMax()
                } label: {
                    Label("Всё на max", systemImage: "sparkles")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .tint(.green)

                Button {
                    onReset()
                } label: {
                    Label("Сброс", systemImage: "arrow.counterclockwise")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .tint(.secondary)

                Button {
                    onSavePlan()
                } label: {
                    Label(isPlanSaved ? "Сохранено" : "Сохранить план", systemImage: isPlanSaved ? "checkmark" : "square.and.arrow.down")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(isPlanSaved ? .green : .blue)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }
}
