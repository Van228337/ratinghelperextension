import SwiftUI

public struct SubjectCardView: View {
    public let subject: Subject
    public let onToggleArchive: () -> Void

    public var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(subject.disciplineName)
                    .font(.headline)
                    .foregroundColor(subject.hasJournal ? .primary : .secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    AssessmentBadgeView(type: subject.assessmentType, small: true)

                    if !subject.hasJournal {
                        Text("Журнал недоступен")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.red)
                    }
                }

                if !subject.instructor.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.crop.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(subject.instructor)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            ProgressRingView(value: subject.rating, size: 60, strokeWidth: 6)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                onToggleArchive()
            } label: {
                Label(subject.isHidden ? "Восстановить" : "В архив", systemImage: subject.isHidden ? "tray.and.arrow.up.fill" : "archivebox.fill")
            }
            .tint(subject.isHidden ? .blue : .gray)
        }
    }
}
