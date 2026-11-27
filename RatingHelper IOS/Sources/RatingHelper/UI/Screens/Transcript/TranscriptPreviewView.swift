import SwiftUI
import Photos

/// Предпросмотр готовой выписки: все страницы, поделиться, сохранить в Фото.
public struct TranscriptPreviewView: View {
    public let images: [UIImage]

    @State private var page: Int = 0
    @State private var showingShare: Bool = false
    @State private var isSaving: Bool = false
    @State private var saveResult: String?

    private let pageAspect: CGFloat = 794.0 / 1123.0

    public init(images: [UIImage]) {
        self.images = images
    }

    public var body: some View {
        VStack(spacing: 0) {
            if images.isEmpty {
                emptyState
            } else {
                TabView(selection: $page) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        ScrollView([.vertical]) {
                            Image(uiImage: image)
                                .resizable()
                                .interpolation(.high)
                                .aspectRatio(pageAspect, contentMode: .fit)
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                                )
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                if images.count > 1 {
                    Text("Страница \(page + 1) из \(images.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)
                }

                actions
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Выписка")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShare) {
            ActivityView(activityItems: images)
        }
        .alert(
            "Фото",
            isPresented: Binding(
                get: { saveResult != nil },
                set: { if !$0 { saveResult = nil } }
            )
        ) {
            Button("OK", role: .cancel) { saveResult = nil }
        } message: {
            Text(saveResult ?? "")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text("Выписка не сформирована")
                .font(.headline)
            Text("Вернитесь к настройкам и попробуйте снова.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                saveToPhotos()
            } label: {
                HStack(spacing: 6) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Image(systemName: "square.and.arrow.down")
                    }
                    Text("Сохранить в Фото")
                }
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isSaving)

            Button {
                showingShare = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Поделиться")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.susuBluePrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private func saveToPhotos() {
        guard !images.isEmpty, !isSaving else { return }
        isSaving = true
        let pages = images

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    isSaving = false
                    saveResult = "Нет разрешения на сохранение в Фото. Разрешите доступ в настройках iOS."
                }
                return
            }

            PHPhotoLibrary.shared().performChanges {
                for image in pages {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    isSaving = false
                    if success {
                        saveResult = pages.count == 1
                            ? "Изображение сохранено в Фото."
                            : "Сохранено страниц: \(pages.count)."
                    } else {
                        saveResult = "Не удалось сохранить: \(error?.localizedDescription ?? "неизвестная ошибка")"
                    }
                }
            }
        }
    }
}
