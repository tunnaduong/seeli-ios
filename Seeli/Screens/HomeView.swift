import SwiftUI

struct HomeView: View {
    @Environment(AppStore.self) private var store
    private let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text(DateText.header(store.now))
                    .font(.system(size: 13))
                    .foregroundStyle(Color.seeliMuted)
                Spacer()
                Button { store.path.append(.profile) } label: {
                    Circle()
                        .fill(Color.seeliCard)
                        .frame(width: 44, height: 44)
                        .overlay(Image(systemName: "person").foregroundStyle(Color.seeliGreen))
                }
                .accessibilityLabel("Profile")
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            Spacer(minLength: 20)

            VStack(spacing: 10) {
                EyeLogo(size: 30)
                Text("SEELI")
                    .font(.system(size: 44, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color.seeliInk)
                Text("See more. Live more.")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.seeliMuted)
            }

            VStack(spacing: 18) {
                Text(t("home.question"))
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(Color.seeliInk)
                    .multilineTextAlignment(.center)
                Button { store.path.append(.camera) } label: {
                    Circle()
                        .fill(Color.seeliGreen)
                        .frame(width: 76, height: 76)
                        .overlay(Image(systemName: "camera").font(.system(size: 24)).foregroundStyle(.white))
                        .shadow(color: Color.seeliGreen.opacity(0.25), radius: 10, y: 4)
                }
                .accessibilityLabel(t("camera.title"))
            }
            .padding(.vertical, 30)
            .frame(maxWidth: .infinity)
            .seeliCard(.seeliCard, radius: 28, border: false)
            .padding(.horizontal, 32)
            .padding(.top, 36)

            if let due = store.dueMoments.first {
                ReunionBanner(count: store.dueMoments.count) {
                    store.path.append(.reunion(due.id))
                }
                .padding(.horizontal, 32)
                .padding(.top, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if store.sleepingCount > 0 {
                Text(tf("home.sleeping", store.sleepingCount))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.seeliMuted)
                    .padding(.top, 16)
            }

            Spacer(minLength: 20)

            Divider().overlay(Color.seeliLine).padding(.horizontal, 24)

            HStack {
                Button { store.path.append(.connect) } label: {
                    Label("Let's connect", systemImage: "person.2")
                        .overlay(alignment: .topLeading) {
                            CountBadge(count: store.connectBadge + store.friendRequests.incoming.count)
                                .offset(x: 14, y: -12)
                        }
                }
                .accessibilityValue(store.connectBadge > 0 ? tf("home.connect.badge", store.connectBadge) : "")
                Spacer()
                Button { store.path.append(.memories) } label: {
                    Label("Memories", systemImage: "folder")
                }
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(Color.seeliInk)
            .padding(.horizontal, 32)
            .padding(.vertical, 26)
        }
        .background(Color.seeliBG.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .animation(.easeInOut, value: store.dueMoments.count)
        .onReceive(timer) { _ in store.refreshClock() }
        .onAppear { store.refreshClock() }
    }
}

private struct ReunionBanner: View {
    var count: Int
    var action: () -> Void
    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.seeliSun.opacity(0.35)).frame(width: 42, height: 42)
                        .scaleEffect(pulse ? 1.15 : 0.95)
                    Image(systemName: "sparkles").foregroundStyle(Color.seeliGreen)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("home.reunion.title"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.seeliInk)
                    Text(count > 1 ? tf("home.reunion.many", count) : t("home.reunion.one"))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.seeliMuted)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Color.seeliMuted)
            }
            .padding(14)
            .seeliCard()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}
