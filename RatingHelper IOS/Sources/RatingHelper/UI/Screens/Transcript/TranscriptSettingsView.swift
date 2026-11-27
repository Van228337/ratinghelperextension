import SwiftUI

/// Настройки формирования выписки с оценками.
/// Точка входа — раздел «Настройки» приложения.
public struct TranscriptSettingsView: View {
    @EnvironmentObject private var appState: AppState

    @State private var variant: TranscriptVariant = .single
    @State private var mode: TranscriptMode = .actual
    @State private var selectedSubjectId: String?
    @State private var drafts: [String: SavedPlan] = [:]
    @State private var isGenerating: Bool = false
    @State private var errorMessage: String?
    @State private var images: [UIImage] = []
    @State private var showingPreview: Bool = false

    private var subjects: [Subject] {
        appState.subjects.filter { !$0.isHidden && $0.termNumber == appState.selectedTerm }
    }

    private var selectedSubject: Subject? {
        subjects.first { $0.id == selectedSubjectId }
    }

    private var selectedSubjectHasDraft: Bool {
        guard let selectedSubject else { return false }
        return drafts[selectedSubject.id] != nil
    }

    private var canGenerate: Bool {
        guard !isGenerating, !subjects.isEmpty else { return false }
        if variant == .single { return selectedSubjectId != nil }
        return true
    }

    public init() {}

    public var body: some View {
        Form {
            Section {
                Picker("Вариант выписки", selection: $variant) {
                    ForEach(TranscriptVariant.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Что включить")
            } footer: {
                Text(variant.summary)
            }

            if variant == .single {
                Section {
                    Picker("Дисциплина", selection: $selectedSubjectId) {
                        Text("Не выбрана").tag(String?.none)
                        ForEach(subjects) { subject in
                            Text(subject.disciplineName).tag(Optional(subject.id))
                        }
                    }

                    Picker("Формат", selection: $mode) {
                        ForEach(TranscriptMode.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Дисциплина и формат")
                } footer: {
                    if mode == .simulated {
                        Text(simulationHint)
                    } else {
                        Text("Фактические баллы на момент формирования.")
                    }
                }
            }

            Section {
                LabeledContent("Семестр", value: "\(appState.selectedTerm) семестр")
                LabeledContent("Дисциплин в выписке", value: "\(variant == .single ? (selectedSubject == nil ? 0 : 1) : subjects.count)")
            } header: {
                Text("Параметры")
            } footer: {
                Text("Учитываются только дисциплины текущего семестра. Архивные дисциплины в выписку не попадают.")
            }

            Section {
                Button {
                    generate()
                } label: {
                    HStack(spacing: 10) {
                        if isGenerating {
                            ProgressView()
                        } else {
                            Image(systemName: "doc.text.magnifyingglass")
                        }
                        Text(isGenerating ? "Формирование…" : "Сформировать выписку")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(!canGenerate)
            }

            if subjects.isEmpty {
                Section {
                    Text("В текущем семестре нет активных дисциплин. Выберите семестр на экране «Дисциплины».")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Выписка с оценками")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showingPreview) {
            TranscriptPreviewView(images: images)
        }
        .task {
            drafts = await LocalStore.shared.loadDrafts()
            if appState.subjects.isEmpty {
                await appState.loadSubjects()
            }
            if selectedSubjectId == nil {
                selectedSubjectId = subjects.first?.id
            }
        }
        .alert(
            "Не удалось сформировать выписку",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var simulationHint: String {
        if selectedSubjectHasDraft {
            return "Будет использован сохранённый план моделирования этой дисциплины: фактические и смоделированные баллы будут показаны рядом. Оценки в ЮУрГУ и приложении не изменяются."
        }
        return "Сохранённого плана моделирования нет. Показываются только фактические баллы — отличий от фактической выписки не будет. Сохранить план можно в журнале дисциплины."
    }

    private func generate() {
        guard canGenerate else { return }
        isGenerating = true
        errorMessage = nil

        Task {
            do {
                let document = try await TranscriptBuilder.shared.build(
                    variant: variant,
                    mode: variant.supportsSimulation ? mode : .actual,
                    subjectId: selectedSubjectId,
                    appState: appState
                )
                let rendered = TranscriptExporter.shared.render(document)
                isGenerating = false
                guard !rendered.isEmpty else {
                    errorMessage = "Не удалось сформировать страницы выписки."
                    return
                }
                images = rendered
                showingPreview = true
            } catch {
                isGenerating = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
