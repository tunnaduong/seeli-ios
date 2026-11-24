import SwiftUI

/// The moment an old photo comes back (~30 days later), or revisiting one.
struct ReunionView: View {
    @Environment(AppStore.self) private var store
    var momentID: String
    @State private var revealed = false
    @State private var reflection = ""
    @State private var saved = false
    @State private var image: UIImage?
    @State private var loading = true
    @FocusState private var focused: Bool

    var body: some View {
        SeeliScreen(title: "REUNION", subtitle: t("reunion.subtitle"), leading: .home) {
            if let moment = store.moment(momentID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(tf("reunion.daysAgo", DateText.daysAgo(moment.createdAt, now: store.now)))
                            .font(.system(size: 13)).foregroundStyle(Color.seeliMuted)
                        Text(DateText.long(moment.createdAt))
                            .font(.system(size: 22, weight: .semibold)).foregroundStyle(Color.seeliInk)
                            .padding(.top, 4)

                        Color.seeliCard
                        .frame(maxWidth: .infinity)
                        .frame(height: 380)
                        .overlay {
                            if let image {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .blur(radius: revealed ? 0 : 30)
                                    .opacity(revealed ? 1 : 0.4)
                                    .scaleEffect(revealed ? 1 : 1.08)
                            } else if loading {
                                ProgressView()
                            } else {
                                EyeLogo(size: 30, closed: true, color: .seeliMuted)
                            }
                        }
                        .frame(height: 380)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .padding(.top, 18)

                        HStack(alignment: .top, spacing: 14) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(t("reunion.then")).font(.system(size: 10, weight: .medium)).tracking(1).foregroundStyle(Color.seeliMuted)
                                NoteText(text: moment.note.isEmpty ? t("memories.noWords") : moment.note, size: 15, perColumn: 9)
                            }
                            Spacer(minLength: 0)
                            VStack(alignment: .trailing, spacing: 6) {
                                if let place = moment.placeName {
                                    Label(place, systemImage: "mappin.circle").font(.system(size: 11))
                                }
                                Text(DateText.stamp(moment.createdAt)).font(.system(size: 11))
                            }
                            .foregroundStyle(Color.seeliMuted)
                        }
                        .padding(18)
                        .seeliCard(.seeliCard, border: false)
                        .padding(.top, 14)
                        .opacity(revealed ? 1 : 0)

                        VStack(alignment: .leading, spacing: 12) {
                            Text(t("reunion.now")).font(.system(size: 18, weight: .semibold)).foregroundStyle(Color.seeliInk)
                            Text(t("reunion.now.hint")).font(.system(size: 12)).foregroundStyle(Color.seeliMuted)
                            TextField(t("reunion.placeholder"), text: $reflection, axis: .vertical)
                                .lineLimit(3...6)
                                .focused($focused)
                                .padding(14)
                                .seeliCard(radius: 14)
                            Button(saved ? t("reunion.saved") : t("reunion.save")) {
                                focused = false
                                Task {
                                    if await store.saveReflection(momentID, text: reflection) {
                                        withAnimation { saved = true }
                                    }
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle(enabled: !reflection.isEmpty))
                            .disabled(reflection.isEmpty)
                        }
                        .padding(.top, 28)
                        .opacity(revealed ? 1 : 0)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
                }
                .scrollDismissesKeyboard(.interactively)
                .task {
                    reflection = moment.reflection ?? ""
                    saved = moment.reflection != nil
                    let first = moment.reunitedAt == nil
                    // Reuniting also returns a fresh, signed photo URL.
                    let fresh = await store.reunite(momentID) ?? moment
                    if let url = fresh.photoUrl.flatMap(URL.init(string:)),
                       let (data, _) = try? await URLSession.shared.data(from: url) {
                        image = UIImage(data: data)
                    }
                    loading = false
                    if first {
                        withAnimation(.easeInOut(duration: 2.2).delay(0.4)) { revealed = true }
                    } else {
                        revealed = true
                    }
                }
                .onChange(of: reflection) { _, _ in saved = false }
            } else {
                Spacer()
                Text(t("friend.gone")).foregroundStyle(Color.seeliMuted)
                Spacer()
            }
        }
    }
}
