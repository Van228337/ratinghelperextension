import SwiftUI

public struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @State private var loginText: String = ""
    @State private var passwordText: String = ""
    @State private var rememberMe: Bool = true
    @State private var isPasswordVisible: Bool = false

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Header logo & branding
                    VStack(spacing: 12) {
                        Image(systemName: "graduationcap.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 76, height: 76)
                            .foregroundColor(.blue)

                        Text("Rating Helper")
                            .font(.title.weight(.bold))

                        Text("Калькулятор БРС и рейтинг ЮУрГУ")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)

                    // Form Fields
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Логин в Универис / SUSU")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.secondary)
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.secondary)
                                    .frame(width: 20)
                                TextField("логин (например, ivanovii)", text: $loginText)
                                    .textContentType(.username)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            }
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Пароль")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.secondary)
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.secondary)
                                    .frame(width: 20)
                                if isPasswordVisible {
                                    TextField("пароль", text: $passwordText)
                                        .textContentType(.password)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                } else {
                                    SecureField("пароль", text: $passwordText)
                                        .textContentType(.password)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                }
                                Button {
                                    isPasswordVisible.toggle()
                                } label: {
                                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }

                        Toggle(isOn: $rememberMe) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Запомнить меня")
                                    .font(.subheadline.weight(.medium))
                                Text("Безопасное сохранение сессии в Keychain")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal)

                    if let err = appState.errorMessage {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(err)
                                .font(.footnote)
                                .foregroundColor(.red)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }

                    // Login Button
                    Button {
                        Task {
                            _ = await appState.login(
                                loginText: loginText.trimmingCharacters(in: .whitespacesAndNewlines),
                                passwordText: passwordText,
                                rememberMe: rememberMe
                            )
                        }
                    } label: {
                        HStack {
                            if appState.isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.trailing, 6)
                            }
                            Text(appState.isLoading ? "Вход..." : "Войти в систему")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(loginText.isEmpty || passwordText.isEmpty ? Color.gray.opacity(0.5) : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .disabled(loginText.isEmpty || passwordText.isEmpty || appState.isLoading)
                    .padding(.horizontal)

                    // Privacy notice
                    VStack(spacing: 6) {
                        Text("🔒 Защита и конфиденциальность")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                        Text("Пароли отправляются исключительно на официальный сервер университета online.susu.ru через защищённое HTTPS-соединение.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 10)
                }
            }
        }
    }
}
