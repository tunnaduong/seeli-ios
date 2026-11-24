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

    var body: some View {
        SeeliScreen(title: "AUDIENCE", subtitle: t("audience.subtitle"), leading: .back) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SectionTitle(title: t("audience.title"), subtitle: t("audience.hint"))
                        .padding(.bottom, 10)
                    ForEach(Audience.allCases) { option in
                        AudienceOption(option: option, selected: audience == option) { audience = option }
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
            }
            VStack(spacing: 14) {
                Button(t("audience.submit")) {
                    store.draft.audience = audience
                    store.commitDraft()
                    store.path = [.posted]
                }
                .buttonStyle(PrimaryButtonStyle())
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
        .onAppear { audience = store.draft.audience }
    }
}

private struct AudienceOption: View {
    var option: Audience
    var selected: Bool
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
                }
                Spacer()
                if disabled {
                    Text(t("audience.soon")).font(.system(size: 11)).foregroundStyle(Color.seeliMuted)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(.white))
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
