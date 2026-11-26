import SwiftUI

struct PostView: View {
    @Environment(AppStore.self) private var store
    @State private var note = ""
    @State private var recordPlace = true
    @State private var placeName: String?
    @State private var locating = false
    @State private var locator = LocationService()
    @FocusState private var focused: Bool
    private let limit = 80

    var body: some View {
        SeeliScreen(title: "POST", subtitle: t("post.subtitle"), leading: .back) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(spacing: 10) {
                        Circle().fill(.white).frame(width: 56, height: 56)
                            .overlay(EyeLogo(size: 22, closed: true))
                        Text(t("post.hidden.title"))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.seeliInk)
                        Text(t("post.hidden.body"))
                            .font(.system(size: 12))
                            .foregroundStyle(Color.seeliMuted)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                        Text(t("post.hidden.auto"))
                            .font(.system(size: 11))
                            .foregroundStyle(Color.seeliMuted)
                            .padding(.top, 6)
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .seeliCard(.seeliCard, radius: 24, border: false)

                    SectionTitle(title: t("post.note.title"), subtitle: t("post.note.subtitle"))
                        .padding(.top, 28)
                        .padding(.bottom, 14)

                    ZStack(alignment: .bottomTrailing) {
                        TextField(t("post.note.placeholder"), text: $note, axis: .vertical)
                            .lineLimit(3...5)
                            .font(.system(size: 15))
                            .focused($focused)
                            .padding(16)
                            .padding(.bottom, 18)
                            .frame(minHeight: 110, alignment: .topLeading)
                            .onChange(of: note) { _, new in
                                if new.count > limit { note = String(new.prefix(limit)) }
                            }
                        Text("\(note.count) / \(limit)")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.seeliMuted)
                            .padding(12)
                    }
                    .seeliCard()

                    HStack(spacing: 12) {
                        Image(systemName: "mappin.and.ellipse").foregroundStyle(Color.seeliGreen)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(t("post.place.title")).font(.system(size: 15, weight: .medium)).foregroundStyle(Color.seeliInk)
                            Text(placeSubtitle).font(.system(size: 12)).foregroundStyle(Color.seeliMuted)
                        }
                        Spacer()
                        Toggle("", isOn: $recordPlace).labelsHidden().tint(.seeliGreen)
                    }
                    .padding(16)
                    .seeliCard()
                    .padding(.top, 16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 10) {
                Button {
                    store.draft.note = note
                    store.draft.recordPlace = recordPlace
                    store.draft.placeName = placeName
                    store.path.append(.audience)
                } label: {
                    HStack {
                        Spacer()
                        Text(t("post.next"))
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 14))
                    }
                    .padding(.horizontal, 20)
                }
                .buttonStyle(PrimaryButtonStyle())
                Text(t("post.next.hint")).font(.system(size: 11)).foregroundStyle(Color.seeliMuted)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .onAppear {
            note = store.draft.note
            recordPlace = store.draft.recordPlace
            placeName = store.draft.placeName
            if recordPlace && placeName == nil { locate() }
        }
        .onChange(of: recordPlace) { _, on in if on && placeName == nil { locate() } }
    }

    private var placeSubtitle: String {
        if !recordPlace { return t("post.place.off") }
        if locating { return t("post.place.locating") }
        if let placeName { return placeName + " · " + t("post.place.private") }
        return t("post.place.private")
    }

    private func locate() {
        locating = true
        Task {
            let name = await locator.currentPlaceName()
            placeName = name
            locating = false
        }
    }
}

struct AudienceView: View {
    @Environment(AppStore.self) private var store
    @State private var audience: Audience = .onlyMe
    @State private var recipients: Set<String> = []
    @State private var managingClose = false

    private var closeCount: Int { store.friends.filter(\.isClose).count }

    private var canSubmit: Bool {
        switch audience {
        case .selected: return !recipients.isEmpty
        case .closeFriends: return closeCount > 0
        default: return true
        }
    }

    var body: some View {
        SeeliScreen(title: "AUDIENCE", subtitle: t("audience.subtitle"), leading: .back) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SectionTitle(title: t("audience.title"), subtitle: t("audience.hint"))
                        .padding(.bottom, 10)
                    ForEach(Audience.allCases) { option in
                        AudienceOption(option: option, selected: audience == option, detail: detail(option)) {
                            withAnimation(.easeInOut(duration: 0.2)) { audience = option }
                        }
                        if option == .closeFriends && audience == .closeFriends {
                            Button { managingClose = true } label: {
                                Label(closeCount == 0 ? t("audience.close.pick") : t("audience.close.manage"), systemImage: "star")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.seeliGreen)
                            }
                            .padding(.leading, 18)
                        }
                        if option == .selected && audience == .selected {
                            FriendPicker(selection: $recipients)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lock").foregroundStyle(Color.seeliMuted)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(t("audience.lock.title")).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.seeliInk)
                            Text(t("audience.lock.body")).font(.system(size: 12)).foregroundStyle(Color.seeliMuted)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .seeliCard(.seeliCard, border: false)
                    .padding(.top, 10)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            VStack(spacing: 14) {
                Button(t("audience.submit")) {
                    store.draft.audience = audience
                    store.draft.recipients = audience == .selected ? Array(recipients) : []
                    store.commitDraft()
                    store.path = [.posted]
                }
                .buttonStyle(PrimaryButtonStyle(enabled: canSubmit))
                .disabled(!canSubmit)
                Button(t("audience.cancel")) {
                    store.draft = Draft()
                    store.path = []
                }
                .font(.system(size: 13))
                .foregroundStyle(Color.seeliMuted)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .onAppear {
            audience = store.draft.audience
            recipients = Set(store.draft.recipients)
        }
        .sheet(isPresented: $managingClose) {
            CloseFriendsSheet().presentationDetents([.medium, .large])
        }
    }

    private func detail(_ option: Audience) -> String? {
        switch option {
        case .closeFriends: return closeCount == 0 ? t("audience.close.none") : tf("audience.close.count", closeCount)
        case .selected: return recipients.isEmpty ? nil : tf("audience.selected.count", recipients.count)
        default: return nil
        }
    }
}

private struct AudienceOption: View {
    var option: Audience
    var selected: Bool
    var detail: String? = nil
    var action: () -> Void

    private var disabled: Bool { option == .everyone }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                if disabled {
                    Image(systemName: "globe").font(.system(size: 20, weight: .light)).foregroundStyle(Color.seeliMuted)
                        .frame(width: 26)
                } else {
                    ZStack {
                        Circle().stroke(selected ? Color.seeliGreen : Color.seeliInk.opacity(0.6), lineWidth: 1.5)
                            .frame(width: 24, height: 24)
                        if selected { Circle().fill(Color.seeliGreen).frame(width: 13, height: 13) }
                    }
                    .frame(width: 26)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(option.badge).font(.system(size: 11, weight: .semibold)).tracking(1.2)
                        .foregroundStyle(disabled ? Color.seeliMuted : Color.seeliInk.opacity(0.8))
                    Text(t(option.descriptionKey)).font(.system(size: 15))
                        .foregroundStyle(disabled ? Color.seeliMuted : Color.seeliInk)
                        .multilineTextAlignment(.leading)
                    if let detail {
                        Text(detail).font(.system(size: 12)).foregroundStyle(Color.seeliGreen)
                    }
                }
                Spacer()
                if disabled {
                    Text(t("audience.soon")).font(.system(size: 11)).foregroundStyle(Color.seeliMuted)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(.white))
                } else {
                    Image(systemName: option.icon).font(.system(size: 15)).foregroundStyle(Color.seeliMuted)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .seeliCard(disabled ? .seeliCard : .seeliSurface, border: !disabled)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.seeliGreen, lineWidth: selected ? 1.5 : 0)
            )
        }
        .disabled(disabled)
        .animation(.easeInOut(duration: 0.15), value: selected)
    }
}

/// Tick the friends who should receive this moment.
struct FriendPicker: View {
    @Environment(AppStore.self) private var store
    @Binding var selection: Set<String>
    @State private var query = ""

    private var shown: [Friend] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let list = store.friends.sorted { ($0.isClose ? 0 : 1, $0.name) < ($1.isClose ? 0 : 1, $1.name) }
        guard !q.isEmpty else { return list }
        return list.filter { $0.name.lowercased().contains(q) || $0.handle.lowercased().contains(q) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if store.friends.isEmpty {
                Text(t("connect.empty")).font(.system(size: 13)).foregroundStyle(Color.seeliMuted)
                    .padding(14)
            } else {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(Color.seeliMuted)
                    TextField(t("picker.search"), text: $query)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    if !selection.isEmpty {
                        Button(t("picker.clear")) { selection.removeAll() }
                            .font(.system(size: 12)).foregroundStyle(Color.seeliGreen)
                    }
                }
                .font(.system(size: 14))
                .padding(.horizontal, 12).frame(height: 40)
                .seeliCard(.seeliCard, radius: 12, border: false)
                VStack(spacing: 0) {
                    ForEach(shown) { f in
                        Button {
                            if selection.contains(f.id) { selection.remove(f.id) } else { selection.insert(f.id) }
                        } label: {
                            HStack(spacing: 12) {
                                Avatar(initial: f.initial, size: 34)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(f.name).font(.system(size: 14, weight: .medium)).foregroundStyle(Color.seeliInk)
                                        if f.isClose { Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(Color.seeliSun) }
                                    }
                                    Text("@\(f.handle)").font(.system(size: 11)).foregroundStyle(Color.seeliMuted)
                                }
                                Spacer()
                                Image(systemName: selection.contains(f.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20))
                                    .foregroundStyle(selection.contains(f.id) ? Color.seeliGreen : Color.seeliMuted.opacity(0.6))
                            }
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selection.contains(f.id) ? .isSelected : [])
                    }
                }
                .seeliCard(radius: 16)
            }
        }
        .padding(.leading, 8)
    }
}

/// Mark which friends are close friends (used by the "Close friends" audience).
struct CloseFriendsSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(t("close.title")).font(.system(size: 18, weight: .semibold))
                Spacer()
                Button(t("common.done")) { dismiss() }.font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.seeliGreen)
            }
            Text(t("close.hint")).font(.system(size: 12)).foregroundStyle(Color.seeliMuted)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(store.friends) { f in
                        Button { Task { await store.setClose(f.id, !f.isClose) } } label: {
                            HStack(spacing: 12) {
                                Avatar(initial: f.initial, size: 34)
                                Text(f.name).font(.system(size: 14, weight: .medium)).foregroundStyle(Color.seeliInk)
                                Spacer()
                                Image(systemName: f.isClose ? "star.fill" : "star")
                                    .font(.system(size: 18))
                                    .foregroundStyle(f.isClose ? Color(hex: 0xD9A93E) : Color.seeliMuted)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .seeliCard(radius: 16)
            }
        }
        .padding(24)
        .background(Color.seeliBG.ignoresSafeArea())
    }
}

/// After posting: let go, put the phone down.
struct PostedView: View {
    @Environment(AppStore.self) private var store
    @State private var phase = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().fill(Color.seeliCard).frame(width: 140, height: 140)
                    .scaleEffect(phase >= 1 ? 1 : 0.6)
                EyeLogo(size: 46, closed: phase >= 1, color: .seeliGreen)
            }
            Text(t("posted.title"))
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color.seeliInk)
                .padding(.top, 36)
                .opacity(phase >= 1 ? 1 : 0)
            Text(t("posted.body"))
                .font(.system(size: 14))
                .foregroundStyle(Color.seeliMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 14)
                .opacity(phase >= 2 ? 1 : 0)
            Text(t("posted.lookUp"))
                .font(SeeliFont.mincho(17))
                .foregroundStyle(Color.seeliInk)
                .multilineTextAlignment(.center)
                .padding(.top, 36)
                .opacity(phase >= 3 ? 1 : 0)
            Spacer()
            Button(t("posted.home")) { store.path = [] }
                .buttonStyle(PrimaryButtonStyle())
                .opacity(phase >= 3 ? 1 : 0)
            Text("SEE MORE. LIVE MORE.")
                .font(.system(size: 10, weight: .medium)).tracking(2)
                .foregroundStyle(Color.seeliMuted)
                .padding(.top, 16)
        }
        .padding(28)
        .background(Color.seeliBG.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .onAppear {
            for step in 1...3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * 0.6) {
                    withAnimation(.easeInOut(duration: 0.7)) { phase = step }
                }
            }
        }
    }
}
