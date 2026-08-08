import SwiftUI

/// Faux écran de verrouillage iOS — la porte d'entrée de l'app.
/// Un code mène au hub, un autre au faux Notes (Trident). Tout autre code :
/// secousse des points + vibration d'erreur, comme un vrai iPhone. Aucune
/// autre issue — pour un curieux, l'app est simplement verrouillée.
struct LockView: View {
    @EnvironmentObject var app: AppState
    @State private var digits: [Int] = []
    @State private var shakeOffset: CGFloat = 0

    private let pad: [(String, String)] = [
        ("1", ""), ("2", "A B C"), ("3", "D E F"),
        ("4", "G H I"), ("5", "J K L"), ("6", "M N O"),
        ("7", "P Q R S"), ("8", "T U V"), ("9", "W X Y Z"),
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                Text("Saisissez le code")
                    .font(.system(size: 19))
                    .foregroundColor(.white)
                    .padding(.bottom, 26)

                HStack(spacing: 22) {
                    ForEach(0..<6, id: \.self) { i in
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 1)
                            .background(Circle().fill(i < digits.count ? Color.white : Color.clear))
                            .frame(width: 13, height: 13)
                    }
                }
                .offset(x: shakeOffset)
                .padding(.bottom, 50)

                VStack(spacing: 16) {
                    ForEach(0..<3, id: \.self) { row in
                        HStack(spacing: 26) {
                            ForEach(0..<3, id: \.self) { col in
                                let (chiffre, lettres) = pad[row * 3 + col]
                                padButton(chiffre, lettres)
                            }
                        }
                    }
                    HStack(spacing: 26) {
                        Color.clear.frame(width: 78, height: 78)
                        padButton("0", "")
                        // Effacer / vide, comme iOS
                        Button {
                            if !digits.isEmpty { digits.removeLast() }
                        } label: {
                            Text(digits.isEmpty ? "" : "Effacer")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .frame(width: 78, height: 78)
                        }
                    }
                }
                Spacer()
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(false)
    }

    private func padButton(_ chiffre: String, _ lettres: String) -> some View {
        Button {
            tape(chiffre)
        } label: {
            VStack(spacing: 1) {
                Text(chiffre).font(.system(size: 34, weight: .regular))
                if !lettres.isEmpty {
                    Text(lettres).font(.system(size: 9, weight: .semibold)).tracking(1)
                }
            }
            .foregroundColor(.white)
            .frame(width: 78, height: 78)
            .background(Circle().fill(Color.white.opacity(0.14)))
        }
    }

    private func tape(_ chiffre: String) {
        guard digits.count < 6, let d = Int(chiffre) else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        digits.append(d)
        guard digits.count == 6 else { return }
        let code = digits.map(String.init).joined()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if app.unlock(code) {
                digits = []
            } else {
                // code inconnu : secousse + vibration d'erreur, puis on efface
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                withAnimation(.linear(duration: 0.07).repeatCount(5, autoreverses: true)) {
                    shakeOffset = 14
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    shakeOffset = 0
                    digits = []
                }
            }
        }
    }
}
