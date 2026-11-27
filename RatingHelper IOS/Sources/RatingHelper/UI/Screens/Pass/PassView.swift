import SwiftUI
import UIKit

/// Полноэкранный электронный пропуск ЮУрГУ.
/// Открывается поверх основного интерфейса, закрывается нажатием в любом месте.
/// Номер пропуска берётся из уже существующей сессии (Keychain) — без сетевых запросов.
public struct PassView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var qrImage: UIImage?
    @State private var isLoaded: Bool = false
    @State private var previousBrightness: CGFloat?

    public init() {}

    public var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { close() }
        .task { await loadTicket() }
        .onAppear { raiseBrightness() }
        .onDisappear { restoreBrightness() }
        .statusBarHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        if let qrImage {
            VStack(spacing: 22) {
                Text("Пропуск ЮУрГУ")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black.opacity(0.72))

                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 330, maxHeight: 330)
                    .background(Color.white)

                VStack(spacing: 6) {
                    Text("Приложите к турникету")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.black.opacity(0.60))
                    Text("Нажмите в любом месте, чтобы закрыть")
                        .font(.system(size: 12))
                        .foregroundColor(.black.opacity(0.38))
                }
            }
            .padding(32)
            .padding(.bottom, 8)
        } else if isLoaded {
            VStack(spacing: 12) {
                Image(systemName: "qrcode")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(.black.opacity(0.22))

                Text("Пропуск недоступен")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black.opacity(0.82))

                Text("Номер пропуска не был получен при входе в аккаунт ЮУрГУ. Выйдите из аккаунта и войдите снова, чтобы обновить данные.")
                    .font(.system(size: 13))
                    .foregroundColor(.black.opacity(0.52))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Нажмите, чтобы закрыть")
                    .font(.system(size: 12))
                    .foregroundColor(.black.opacity(0.35))
                    .padding(.top, 6)
            }
            .padding(40)
            .frame(maxWidth: 340)
        } else {
            ProgressView()
                .tint(.black)
        }
    }

    private func loadTicket() async {
        guard !isLoaded else { return }
        let ticket = await SusuAuthService.shared.currentPassTicket()
        if let ticket, let image = QRCodeGenerator.makeImage(from: ticket) {
            qrImage = image
        }
        isLoaded = true
    }

    private func close() {
        restoreBrightness()
        dismiss()
    }

    /// Низкая яркость экрана — частая причина нечитаемого кода на турникете,
    /// поэтому на время показа пропуска яркость поднимается и затем возвращается.
    private func raiseBrightness() {
        let screen = UIScreen.main
        if previousBrightness == nil { previousBrightness = screen.brightness }
        if screen.brightness < 0.9 { screen.brightness = 0.9 }
    }

    private func restoreBrightness() {
        guard let previousBrightness else { return }
        UIScreen.main.brightness = previousBrightness
        self.previousBrightness = nil
    }
}
