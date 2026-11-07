import SwiftUI
import QuickLook

public struct ActivityView: UIViewControllerRepresentable {
    public let activityItems: [Any]
    public let applicationActivities: [UIActivity]? = nil

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

public struct MaterialsView: View {
    @Environment(\.dismiss) private var dismiss
    public let checkpoint: CheckpointItem
    public let subjectId: String
    public let teacherName: String

    @State private var materials: [MaterialItem] = []
    @State private var userVotes: [String: String] = [:]
    @State private var isLoading: Bool = true
    @State private var showingUploadSheet: Bool = false

    // File download & preview
    @State private var downloadingItem: MaterialItem? = nil
    @State private var downloadedLocalURL: URL? = nil
    @State private var showingShareSheet: Bool = false
    @State private var downloadErrorMessage: String? = nil

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Checkpoint Header Card
                    VStack(alignment: .leading, spacing: 6) {
                        Text(checkpoint.title)
                            .font(.headline)
                        HStack {
                            Text("Максимум: \(String(format: "%g", checkpoint.max)) б.")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Материалов: \(materials.count)")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(14)
                    .padding(.horizontal)

                    if let err = downloadErrorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal)
                    }

                    // Materials List
                    if isLoading && materials.isEmpty {
                        ProgressView()
                            .padding(.top, 40)
                    } else if materials.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "folder.badge.questionmark")
                                .font(.system(size: 44))
                                .foregroundColor(.secondary)
                            Text("Материалов пока нет")
                                .font(.headline)
                            Text("К этой работе ещё никто не прикрепил методичку или пример отчёта. Загрузите свою работу первым! 🚀")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .padding(.top, 40)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(materials) { item in
                                materialCard(item)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Материалы к работе")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingUploadSheet = true
                    } label: {
                        Label("Загрузить", systemImage: "arrow.up.doc.fill")
                    }
                }
            }
            .task {
                await loadMaterials()
            }
            .sheet(isPresented: $showingUploadSheet) {
                UploadMaterialSheet(
                    checkpoint: checkpoint,
                    subjectId: subjectId,
                    teacherName: teacherName
                ) {
                    Task { await loadMaterials() }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = downloadedLocalURL {
                    ActivityView(activityItems: [url])
                }
            }
        }
    }

    private func loadMaterials() async {
        isLoading = true
        let list = await SupabaseService.shared.getMaterialsForCheckpoint(checkpointId: checkpoint.id)
        self.materials = list
        self.userVotes = await LocalStore.shared.loadMaterialVotes()
        isLoading = false
    }

    private func materialCard(_ item: MaterialItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)

                    HStack(spacing: 6) {
                        Text("📅 \(item.year) г.")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        if item.isFresh {
                            Text("🔥 Свежая")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(.orange)
                        }

                        if let t = item.teacherName, !t.isEmpty {
                            Text("• 👨‍🏫 \(t)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()
            }

            Divider()

            HStack {
                // Open / Download button
                Button {
                    openOrDownload(item)
                } label: {
                    HStack(spacing: 4) {
                        if downloadingItem?.id == item.id {
                            ProgressView()
                                .tint(.blue)
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                        }
                        Text(downloadingItem?.id == item.id ? "Скачивание..." : "Открыть / Скачать")
                            .font(.caption.weight(.bold))
                    }
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .disabled(downloadingItem != nil)

                Spacer()

                // Vote Buttons
                let vote = userVotes[item.id]
                HStack(spacing: 4) {
                    Button {
                        handleVote(item, isUpvote: true)
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.up")
                            Text("\(item.upvotes)")
                        }
                        .font(.caption2.weight(.bold))
                        .foregroundColor(vote == "up" ? .green : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(vote == "up" ? Color.green.opacity(0.15) : Color(.tertiarySystemFill))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    Button {
                        handleVote(item, isUpvote: false)
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.down")
                            Text("\(item.downvotes)")
                        }
                        .font(.caption2.weight(.bold))
                        .foregroundColor(vote == "down" ? .red : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(vote == "down" ? Color.red.opacity(0.15) : Color(.tertiarySystemFill))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func handleVote(_ item: MaterialItem, isUpvote: Bool) {
        let prevVote = userVotes[item.id]
        Task {
            do {
                let res = try await SupabaseService.shared.voteMaterial(
                    materialId: item.id,
                    isUpvote: isUpvote,
                    previousVote: prevVote
                )
                if let idx = materials.firstIndex(where: { $0.id == item.id }) {
                    materials[idx].upvotes = res.up
                    materials[idx].downvotes = res.down
                }

                if (isUpvote && prevVote == "up") || (!isUpvote && prevVote == "down") {
                    userVotes.removeValue(forKey: item.id)
                    await LocalStore.shared.saveMaterialVote(materialId: item.id, vote: nil)
                } else {
                    let newVote = isUpvote ? "up" : "down"
                    userVotes[item.id] = newVote
                    await LocalStore.shared.saveMaterialVote(materialId: item.id, vote: newVote)
                }
            } catch {
                print("Vote error: \(error)")
            }
        }
    }

    private func openOrDownload(_ item: MaterialItem) {
        guard let url = URL(string: item.fileUrl) else {
            downloadErrorMessage = "Некорректная ссылка на файл"
            return
        }

        // If it's a web link or drive folder, try downloading or open in Safari
        if !item.fileUrl.hasPrefix("http") {
            downloadErrorMessage = "Неподдерживаемый протокол файла"
            return
        }

        downloadingItem = item
        downloadErrorMessage = nil

        Task {
            do {
                let (tempURL, _) = try await URLSession.shared.download(from: url)
                let ext = url.pathExtension.isEmpty ? "pdf" : url.pathExtension
                let targetURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("\(item.title).\(ext)")

                try? FileManager.default.removeItem(at: targetURL)
                try FileManager.default.moveItem(at: tempURL, to: targetURL)

                self.downloadedLocalURL = targetURL
                self.downloadingItem = nil
                self.showingShareSheet = true
            } catch {
                self.downloadingItem = nil
                // Fallback: open via standard openURL
                if UIApplication.shared.canOpenURL(url) {
                    await UIApplication.shared.open(url)
                } else {
                    self.downloadErrorMessage = "Не удалось открыть файл: \(error.localizedDescription)"
                }
            }
        }
    }
}
