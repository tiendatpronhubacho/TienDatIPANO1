import SwiftUI

struct PatchUnlockPrompt: View {
    @ObservedObject var store: PatchProjectStore
    @Environment(\.appLanguage) private var language
    @State private var input: String = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)

                Text("PATCH ĐƯỢC KHOÁ")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(.white)

                Text("Nhập mật khẩu để mở khoá patch này")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)

                SecureField("Mật khẩu", text: $input)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                    )
                    .foregroundStyle(.white)
                    .disabled(store.isBusy)

                if let errorKey = store.unlockErrorKey {
                    Text(language.text(errorKey))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }

                HStack(spacing: 12) {
                    Button {
                        store.cancelUnlock()
                    } label: {
                        Text("Huỷ")
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                    }
                    .disabled(store.isBusy)

                    Button {
                        store.unlock(password: input)
                    } label: {
                        Group {
                            if store.isBusy {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Text("Mở khoá")
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.black)
                    }
                    .disabled(input.isEmpty || store.isBusy)
                    .opacity(input.isEmpty ? 0.4 : 1)
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .padding(28)
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
        .onAppear { store.clearUnlockError() }
    }
}