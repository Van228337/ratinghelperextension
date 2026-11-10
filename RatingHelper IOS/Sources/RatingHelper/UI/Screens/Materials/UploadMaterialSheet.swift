import SwiftUI
import UniformTypeIdentifiers

public struct UploadMaterialSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    public let checkpoint: CheckpointItem
    public let subjectId: String
    public let teacherName: String
    public let onUploaded: () -> Void

    @State private var title: String = ""
    @State private var externalUrl: String = ""
    @State private var year: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedFileData: Data? = nil
    @State private var selectedFileName: String? = nil
    @State private var selectedMimeType: String = "application/octet-stream"
    @State private var showingFileImporter: Bool = false
    @State private var isUploading: Bool = false
    @State private var statusMessage: String? = nil
    @State private var isError: Bool = false

    private let years = [2026, 2025, 2024, 2023, 2022]
    private let maxFileSize: Int = 20 * 1024 * 1024 // 20 MB

    public var body: some View {
        NavigationStack {
            Form {
                if !appState.canUploadFiles {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.raised.fill")
                                .foregroundColor(.orange)
                            Text("Загрузка файлов для вашей учётной записи отключена администратором.")
                                .font(.footnote)
                                .foregroundColor(.orange)
                        }
                    }
                }

                Section(header: Text("Контрольная точка")) {
                    Text(checkpoint.title)
                        .font(.headline)
                    Text("Максимум: \(String(format: "%g", checkpoint.max)) б.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Файл документа")) {
                    if let fname = selectedFileName, let data = selectedFileData {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(fname)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                                Text(String(format: "Размер: %.2f МБ", Double(data.count) / 1024.0 / 1024.0))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Изменить") {
                                showingFileImporter = true
                            }
                            .font(.caption)
                        }
                    } else {
                        Button {
                            showingFileImporter = true
                        } label: {
                            Label("Выбрать файл на устройстве", systemImage: "doc.badge.plus")
                        }
                    }

                    Text("Или укажите внешнюю ссылку:")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    TextField("https://...", text: $externalUrl)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }

                Section(header: Text("Сведения о материале")) {
                    TextField("Название работы / методички", text: $title)

                    Picker("Год выполнения", selection: $year) {
                        ForEach(years, id: \.self) { y in
                            Text("\(y) год").tag(y)
                        }
                    }
                }

                if let msg = statusMessage {
                    Section {
                        HStack {
                            Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .foregroundColor(isError ? .red : .green)
                            Text(msg)
                                .font(.footnote)
                                .foregroundColor(isError ? .red : .green)
                        }
                    }
                }
            }
            .navigationTitle("Загрузить материал")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        uploadMaterial()
                    } label: {
                        if isUploading {
                            ProgressView()
                        } else {
                            Text("Опубликовать")
                                .fontWeight(.bold)
                        }
                    }
                    .disabled(!appState.canUploadFiles || (selectedFileData == nil && externalUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) || isUploading)
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.pdf, .text, .rtf, .image, .zip, .archive, .item],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let fileURL = urls.first else { return }
                    loadFile(from: fileURL)
                case .failure(let err):
                    isError = true
                    statusMessage = "Ошибка выбора файла: \(err.localizedDescription)"
                }
            }
        }
    }

    private func loadFile(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            isError = true
            statusMessage = "Нет доступа к выбранному файлу"
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            if data.count > maxFileSize {
                isError = true
                statusMessage = "Файл слишком большой (\(data.count / 1024 / 1024) МБ). Лимит: 20 МБ."
                return
            }

            self.selectedFileData = data
            self.selectedFileName = url.lastPathComponent
            if title.isEmpty {
                self.title = url.deletingPathExtension().lastPathComponent
            }
            isError = false
            statusMessage = nil
        } catch {
            isError = true
            statusMessage = "Не удалось прочитать файл: \(error.localizedDescription)"
        }
    }

    private func uploadMaterial() {
        guard appState.canUploadFiles else {
            isError = true
            statusMessage = "Загрузка файлов отключена администратором."
            return
        }
        guard UUID(uuidString: checkpoint.id) != nil else {
            isError = true
            statusMessage = "Контрольная точка ещё не синхронизирована с Supabase. Обновите журнал и повторите попытку."
            return
        }
        guard UUID(uuidString: subjectId) != nil else {
            isError = true
            statusMessage = "У дисциплины некорректный идентификатор Supabase."
            return
        }
        isUploading = true
        statusMessage = "Загрузка файла на Google Диск..."
        isError = false

        Task {
            var uploadedResult: GoogleDriveUploadResult? = nil
            do {
                var fileLink = externalUrl.trimmingCharacters(in: .whitespacesAndNewlines)

                if let data = selectedFileData, let fname = selectedFileName {
                    let result = try await GoogleDriveService.shared.uploadFile(
                        data: data,
                        fileName: fname,
                        mimeType: selectedMimeType,
                        subjectId: subjectId,
                        checkpointId: checkpoint.id
                    )
                    uploadedResult = result
                    fileLink = result.fileUrl
                }

                statusMessage = "Сохранение в базу..."

                _ = try await SupabaseService.shared.addMaterialRecord(
                    checkpointId: checkpoint.id,
                    subjectId: subjectId,
                    teacherName: teacherName,
                    title: title.isEmpty ? (selectedFileName ?? "Материал") : title,
                    fileUrl: fileLink,
                    fileName: selectedFileName ?? "Ссылка",
                    year: year,
                    userId: appState.effectiveUserId,
                    fileSizeBytes: uploadedResult?.fileSizeBytes ?? 0,
                    fileSha256: uploadedResult?.fileSha256,
                    driveFileId: uploadedResult?.fileId
                )

                isUploading = false
                isError = false
                statusMessage = "Материал успешно загружен!"
                onUploaded()
                try? await Task.sleep(nanoseconds: 600_000_000)
                dismiss()
            } catch {
                if let driveId = uploadedResult?.fileId, !driveId.isEmpty {
                    // Удаляем файл-сироту с Google Диска при сбое записи в БД
                    await GoogleDriveService.shared.deleteFile(fileId: driveId)
                }
                isUploading = false
                isError = true
                statusMessage = "Ошибка загрузки: \(error.localizedDescription)"
            }
        }
    }
}
