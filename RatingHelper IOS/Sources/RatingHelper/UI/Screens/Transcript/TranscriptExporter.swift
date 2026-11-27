import SwiftUI

/// Рендерит выписку в набор изображений формата A4.
/// Каждый блок измеряется отдельно, чтобы страницы не обрезали текст
/// и не переполнялись; при нехватке места создаётся новая страница.
@MainActor
public final class TranscriptExporter {
    public static let shared = TranscriptExporter()

    public let pageWidth: CGFloat = 794
    public let pageHeight: CGFloat = 1123

    private let horizontalPadding: CGFloat = 56
    private let topPadding: CGFloat = 50
    private let bottomPadding: CGFloat = 36
    private let contentGap: CGFloat = 16
    private let renderScale: CGFloat = 2

    private init() {}

    public var contentWidth: CGFloat { pageWidth - horizontalPadding * 2 }

    public func render(_ document: TranscriptDocument) -> [UIImage] {
        let groups = buildGroups(for: document)

        let firstHeader = block(TranscriptDocumentHeader(document: document))
        let continuationHeader = block(TranscriptContinuationHeader(document: document))
        let footer = block(TranscriptPageFooter(index: 1, total: 1))

        let innerHeight = pageHeight - topPadding - bottomPadding
        let firstCapacity = innerHeight - firstHeader.height - footer.height - contentGap
        let nextCapacity = innerHeight - continuationHeader.height - footer.height - contentGap

        let pages = paginate(groups: groups, firstCapacity: firstCapacity, nextCapacity: nextCapacity)
        let total = pages.count

        return pages.enumerated().compactMap { index, pageBlocks in
            renderPage(
                blocks: pageBlocks,
                document: document,
                index: index + 1,
                total: total
            )
        }
    }

    // MARK: - Построение блоков

    private struct MeasuredBlock {
        let view: AnyView
        let height: CGFloat
    }

    private struct RenderGroup {
        let header: MeasuredBlock?
        let continuation: MeasuredBlock?
        let columnHeader: MeasuredBlock
        let rows: [MeasuredBlock]
        let summary: MeasuredBlock?
    }

    private func buildGroups(for document: TranscriptDocument) -> [RenderGroup] {
        switch document.variant {
        case .single:
            guard let discipline = document.disciplines.first else { return [] }
            return [group(for: discipline, isFirst: true)]

        case .allDisciplines:
            if document.disciplines.isEmpty {
                return [emptyGroup(text: "В текущем семестре нет активных дисциплин.")]
            }
            return document.disciplines.enumerated().map { index, discipline in
                group(for: discipline, isFirst: index == 0)
            }

        case .overall:
            if document.disciplines.isEmpty {
                return [emptyGroup(text: "В текущем семестре нет активных дисциплин.")]
            }
            let debtCount = document.disciplines.filter { $0.factRating < 59.01 }.count
            let header = block(
                TranscriptOverviewSummary(
                    average: document.averageRating,
                    count: document.disciplines.count,
                    debtCount: debtCount
                )
            )
            let columnHeader = block(TranscriptOverviewTableHeader())
            let rows = document.disciplines.enumerated().map { index, discipline in
                block(TranscriptOverviewRow(index: index + 1, discipline: discipline))
            }
            return [
                RenderGroup(
                    header: header,
                    continuation: nil,
                    columnHeader: columnHeader,
                    rows: rows,
                    summary: nil
                )
            ]
        }
    }

    private func group(for discipline: TranscriptDiscipline, isFirst: Bool) -> RenderGroup {
        let columnHeader = block(TranscriptCheckpointsTableHeader(showsPlan: discipline.hasPlan))

        var rows: [MeasuredBlock] = []
        if discipline.checkpoints.isEmpty {
            if discipline.checkpointsUnavailable {
                rows.append(block(TranscriptCheckpointsUnavailableNote()))
            } else {
                rows.append(block(TranscriptEmptyNote(text: "В журнале нет контрольных точек.")))
            }
        } else {
            rows = discipline.checkpoints.map { checkpoint in
                block(
                    TranscriptCheckpointRow(
                        checkpoint: checkpoint,
                        showsPlan: discipline.hasPlan
                    )
                )
            }
        }

        let summary: MeasuredBlock?
        if discipline.hasPlan {
            summary = block(TranscriptRatingSummary(discipline: discipline))
        } else {
            // Обычная выписка и дисциплины без журнала: одна строка с текущим рейтингом.
            summary = block(TranscriptDisciplineFooterRow(discipline: discipline))
        }

        return RenderGroup(
            header: block(TranscriptDisciplineHeader(discipline: discipline, isFirst: isFirst)),
            continuation: block(TranscriptDisciplineContinuation(discipline: discipline)),
            columnHeader: columnHeader,
            rows: rows,
            summary: summary
        )
    }

    private func emptyGroup(text: String) -> RenderGroup {
        RenderGroup(
            header: nil,
            continuation: nil,
            columnHeader: block(TranscriptEmptyNote(text: text)),
            rows: [],
            summary: nil
        )
    }

    // MARK: - Измерение и пагинация

    private func block<V: View>(_ view: V) -> MeasuredBlock {
        let constrained = AnyView(view.frame(width: contentWidth, alignment: .leading))
        return MeasuredBlock(view: constrained, height: measureHeight(constrained))
    }

    private func measureHeight(_ view: AnyView) -> CGFloat {
        let renderer = ImageRenderer(
            content: view.fixedSize(horizontal: false, vertical: true)
        )
        renderer.scale = 1
        renderer.isOpaque = false
        guard let image = renderer.uiImage else { return 0 }
        return image.size.height.rounded(.up)
    }

    private func paginate(
        groups: [RenderGroup],
        firstCapacity: CGFloat,
        nextCapacity: CGFloat
    ) -> [[MeasuredBlock]] {
        var pages: [[MeasuredBlock]] = []
        var current: [MeasuredBlock] = []
        var used: CGFloat = 0

        func capacity() -> CGFloat {
            pages.isEmpty ? firstCapacity : nextCapacity
        }

        func breakPage(repeating group: RenderGroup?) {
            guard !current.isEmpty else { return }
            pages.append(current)
            current = []
            used = 0

            if let group {
                if let continuation = group.continuation {
                    current.append(continuation)
                    used += continuation.height
                }
                current.append(group.columnHeader)
                used += group.columnHeader.height
            }
        }

        for group in groups {
            let headHeight = group.header?.height ?? 0
            let firstRowHeight = group.rows.first?.height ?? 0
            let needed = headHeight + group.columnHeader.height + min(firstRowHeight, 80)

            if !current.isEmpty && used + needed > capacity() {
                breakPage(repeating: nil)
            }

            if let header = group.header {
                if !current.isEmpty && used + header.height + group.columnHeader.height > capacity() {
                    breakPage(repeating: nil)
                }
                current.append(header)
                used += header.height
            }

            current.append(group.columnHeader)
            used += group.columnHeader.height

            for row in group.rows {
                if !current.isEmpty && used + row.height > capacity() {
                    breakPage(repeating: group)
                }
                current.append(row)
                used += row.height
            }

            if let summary = group.summary {
                if !current.isEmpty && used + summary.height > capacity() {
                    breakPage(repeating: group)
                }
                current.append(summary)
                used += summary.height
            }
        }

        if !current.isEmpty {
            pages.append(current)
        }
        return pages
    }

    // MARK: - Отрисовка страницы

    private func renderPage(
        blocks: [MeasuredBlock],
        document: TranscriptDocument,
        index: Int,
        total: Int
    ) -> UIImage? {
        let page = TranscriptPageView(
            document: document,
            blocks: blocks.map(\.view),
            isFirst: index == 1,
            index: index,
            total: total
        )

        let renderer = ImageRenderer(content: page)
        renderer.scale = renderScale
        renderer.isOpaque = true
        return renderer.uiImage
    }
}
