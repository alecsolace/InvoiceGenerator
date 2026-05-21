import SwiftUI

/// Circular avatar showing client initials with an accent color background.
struct ClientAvatarView: View {
    let name: String
    let accentColor: Color
    var size: CGFloat = 44

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(accentColor.gradient, in: Circle())
    }

    private var initials: String {
        let words = name.split(separator: " ")
        let first = words.first?.prefix(1) ?? ""
        let second = words.dropFirst().first?.prefix(1) ?? ""
        return "\(first)\(second)".uppercased()
    }
}

#Preview {
    HStack(spacing: 16) {
        ClientAvatarView(name: "Acme Corp S.L.", accentColor: .blue)
        ClientAvatarView(name: "Marta Dominguez", accentColor: .orange)
        ClientAvatarView(name: "TechSolutions", accentColor: .green, size: 56)
    }
    .padding()
}
