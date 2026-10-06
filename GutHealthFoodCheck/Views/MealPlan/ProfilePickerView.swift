import SwiftUI

/// First-launch screen: asks who is using this phone and remembers the answer.
struct ProfilePickerView: View {
    @AppStorage(Profile.storageKey) private var profileRaw = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Who's using this phone?")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            VStack(spacing: 16) {
                ForEach(Profile.allCases) { profile in
                    Button {
                        profileRaw = profile.rawValue
                    } label: {
                        Text(profile.displayName)
                            .font(.title2.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            Spacer()
        }
        .padding(24)
    }
}
