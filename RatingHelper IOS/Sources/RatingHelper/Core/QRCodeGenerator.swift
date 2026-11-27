import UIKit
import CoreImage

/// Локальная генерация QR-кода средствами Core Image.
/// Никакие данные наружу не отправляются: весь путь — строка → фильтр → CGImage.
public enum QRCodeGenerator {
    private static let context = CIContext(options: nil)
    private static var cache: [String: UIImage] = [:]

    /// Создаёт чёткое чёрно-белое изображение QR-кода.
    /// - Parameters:
    ///   - string: содержимое кода.
    ///   - scale: коэффициент увеличения модулей (без сглаживания при выводе).
    public static func makeImage(from string: String, scale: CGFloat = 14) -> UIImage? {
        guard !string.isEmpty else { return nil }
        if let cached = cache[string] { return cached }

        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(string.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }

        let image = UIImage(cgImage: cgImage)
        if cache.count >= 4 { cache.removeAll() }
        cache[string] = image
        return image
    }
}
