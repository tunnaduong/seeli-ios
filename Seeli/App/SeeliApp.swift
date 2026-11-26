import SwiftUI

@main
struct SeeliApp: App {
    @UIApplicationDelegateAdaptor(SeeliAppDelegate.self) private var appDelegate
    @State private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(\.locale, L10n.shared.language.locale)
                .tint(.seeliGreen)
                .preferredColorScheme(store.colorScheme)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        store.refreshClock()
                        Task { await store.refresh() }
                    }
                    if phase == .background { store.updateWidgets(); store.forgetOncePhotos() }
                }
        }
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Group {
            if store.isLoggedIn && !store.welcomePending {
                MainFlow()
                    .transition(.opacity)
            } else {
                AuthFlow()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: store.isLoggedIn)
    }
}

struct MainFlow: View {
    @Environment(AppStore.self) private var store
    @State private var showWhatsNew = false

    var body: some View {
        @Bindable var store = store
        NavigationStack(path: $store.path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    destination(route)
                }
        }
        .sheet(item: $store.pendingInvite) { invite in
            AddFriendView(invite: invite)
                .presentationDetents([.medium, .large])
        }
        .onOpenURL { url in store.handle(url) }
        .sheet(isPresented: $showWhatsNew) { WhatsNewView() }
        .task {
            // Once per new version, a moment after opening (not over a pending invite).
            guard WhatsNew.isPending else { return }
            try? await Task.sleep(for: .milliseconds(600))
            if store.pendingInvite == nil { showWhatsNew = true }
        }
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .camera: CameraView()
        case .post: PostView()
        case .audience: AudienceView()
        case .posted: PostedView()
        case .connect: ConnectView()
        case .memories: MemoriesView()
        case .profile: ProfileView()
        case .friends: FriendsView()
        case .friend(let id): FriendProfileView(friendID: id)
        case .privacy: PrivacyView()
        case .settings: SettingsView()
        case .verified: VerifiedView()
        case .requests: FriendRequestsView()
        case .scan: QRScanView()
        case .myQR: MyQRView()
        case .reunion(let id): ReunionView(momentID: id)
        case .moment(let id): ReunionView(momentID: id)
        }
    }
}
