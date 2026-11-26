import SwiftUI

struct MemoriesView: View {
    @Environment(AppStore.self) private var store
    @State private var month: Date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
    @State private var deleting: Moment?
    @State private var viewingComments: Moment?

    private var cal: Calendar { Calendar.current }

    private var inMonth: [Moment] {
        store.allMoments
            .filter { cal.isDate($0.createdAt, equalTo: month, toGranularity: .month) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        SeeliScreen(title: "MY MEMORIES", subtitle: t("memories.subtitle")) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            let c = cal.dateComponents([.year, .month], from: month)
                            Text(DateText.monthTitle(year: c.year ?? 0, month: c.month ?? 0))
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(Color.seeliInk)
                            Text(tf("memories.count", inMonth.count))
                                .font(.system(size: 13))
                                .foregroundStyle(Color.seeliMuted)
                        }
                        Spacer()
                        monthButton("chevron.left") { shift(-1) }
                        monthButton("chevron.right") { shift(1) }
                            .disabled(isCurrentMonth)
                            .opacity(isCurrentMonth ? 0.4 : 1)
                    }
                    .padding(.bottom, 16)

                    Divider().overlay(Color.seeliLine).padding(.bottom, 16)

                    if inMonth.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "text.quote").font(.system(size: 26, weight: .light))
                            Text(t("memories.empty")).multilineTextAlignment(.center)
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(Color.seeliMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(inMonth) { moment in
                                MemoryCard(moment: moment,
                                           onOpen: { store.path.append(.moment(moment.id)) },
                                           onComments: { viewingComments = moment },
                                           onDelete: { deleting = moment })
                            }
                        }
                    }

                    Text(t("memories.footer"))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.seeliMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
        .confirmationDialog(t("memories.delete.title"), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button(t("common.delete"), role: .destructive) {
                if let d = deleting { Task { await store.deleteMoment(d.id) } }
                deleting = nil
            }
            Button(t("common.cancel"), role: .cancel) { deleting = nil }
        } message: {
            Text(t("memories.delete.body"))
        }
        .task(id: store.pendingCommentsMoment.map { "\($0)-\(store.moments.count)" }) { openPendingComments() }
        .sheet(item: $viewingComments) { moment in
            CommentsSheet(moment: moment).presentationDetents([.medium, .large])
        }
    }

    /// Opened from a notification: jump to that photo's month and show its comments.
    private func openPendingComments() {
        guard let id = store.pendingCommentsMoment, let m = store.moment(id) else { return }
        store.pendingCommentsMoment = nil
        month = cal.date(from: cal.dateComponents([.year, .month], from: m.createdAt)) ?? month
        viewingComments = m
    }

    private var isCurrentMonth: Bool { cal.isDate(month, equalTo: Date(), toGranularity: .month) }

    private func shift(_ n: Int) {
        if let m = cal.date(byAdding: .month, value: n, to: month) { withAnimation { month = m } }
    }

    private func monthButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle().fill(Color.seeliCard).frame(width: 40, height: 40)
                .overlay(Image(systemName: icon).font(.system(size: 14, weight: .medium)).foregroundStyle(Color.seeliInk))
        }
    }
}

private struct MemoryCard: View {
    var moment: Moment
    var onOpen: () -> Void
    var onComments: () -> Void
    var onDelete: () -> Void

    private var ja: Bool { L10n.shared.language == .ja }
    private var noteText: String { moment.note.isEmpty ? t("memories.noWords") : moment.note }

    var body: some View {
        VStack(spacing: 0) {
            // Sleeping moments can't be opened yet, but must not look disabled.
            Button { if moment.isRevealed { onOpen() } } label: {
                if ja { jaLayout } else { viLayout }
            }
            .buttonStyle(.plain)

            Divider().overlay(Color.seeliLine).padding(.horizontal, 12)

            HStack {
                Button(action: onComments) {
                    Label(tf("memories.comments", moment.commentCount), systemImage: "bubble.left")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.seeliInk)
                }
                Spacer()
                if moment.isRevealed {
                    Label(t("memories.reunited"), systemImage: "sparkles")
                        .font(.system(size: 11)).foregroundStyle(Color.seeliGreen)
                } else {
                    Label(moment.isPending == true ? t("memories.uploading") : t("memories.sleeping"),
                          systemImage: moment.isPending == true ? "icloud.and.arrow.up" : "moon.zzz")
                        .font(.system(size: 11)).foregroundStyle(Color.seeliMuted)
                }
                Button(action: onDelete) {
                    Image(systemName: "trash").font(.system(size: 13)).foregroundStyle(Color.seeliMuted)
                        .frame(width: 36, height: 30)
                }
                .accessibilityLabel(t("common.delete"))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .seeliCard(radius: 24)
    }

    private var jaLayout: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading) {
                Text("その日のことば").font(.system(size: 9)).foregroundStyle(Color.seeliMuted)
                Spacer()
                if let place = moment.placeName {
                    VStack(spacing: 4) {
                        Image(systemName: "mappin.circle").font(.system(size: 12)).foregroundStyle(Color.seeliMuted)
                        MetaText(text: place, size: 10, perColumn: 10)
                    }
                    .padding(.leading, 10)
                }
            }
            .frame(width: 70)
            NoteText(text: noteText, size: 15, perColumn: 9)
                .frame(maxWidth: .infinity, minHeight: 210)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.seeliCard))
            MetaText(text: DateText.stamp(moment.createdAt), size: 10, perColumn: 30)
        }
        .padding(12)
    }

    private var viLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("memories.wordsOfDay")).font(.system(size: 10)).foregroundStyle(Color.seeliMuted)
            NoteText(text: noteText, size: 16)
                .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.seeliCard))
            HStack {
                if let place = moment.placeName {
                    Label(place, systemImage: "mappin.circle")
                }
                Spacer()
                Text(DateText.stamp(moment.createdAt))
            }
            .font(.system(size: 11))
            .foregroundStyle(Color.seeliMuted)
        }
        .padding(14)
    }
}

private struct CommentsSheet: View {
    @Environment(AppStore.self) private var store
    var moment: Moment
    @State private var comments: [Comment] = []
    @State private var loading = true
    @State private var replyingTo: String?
    @State private var draft = ""
    @State private var sending = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(t("comments.title")).font(.system(size: 18, weight: .semibold)).foregroundStyle(Color.seeliInk)
            Text(t("connect.privacy")).font(.system(size: 11)).foregroundStyle(Color.seeliMuted)
            if loading {
                Spacer()
                ProgressView().frame(maxWidth: .infinity)
                Spacer()
            } else if comments.isEmpty {
                Spacer()
                Text(t("comments.empty"))
                    .font(.system(size: 13)).foregroundStyle(Color.seeliMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(comments) { c in commentCard(c) }
                    }
                }
            }
        }
        .padding(24)
        .background(Color.seeliBG.ignoresSafeArea())
        .task {
            if moment.isPending != true { comments = await store.comments(for: moment.id) }
            loading = false
        }
    }

    private func commentCard(_ c: Comment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Avatar(initial: c.author.initial, size: 32)
                VStack(alignment: .leading, spacing: 4) {
                    Text(c.author.name).font(.system(size: 13, weight: .semibold))
                    Text(c.text).font(.system(size: 14)).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            if replyingTo == c.id {
                HStack(alignment: .bottom, spacing: 8) {
                    TextField(t("comments.reply.placeholder"), text: $draft, axis: .vertical)
                        .lineLimit(1...4)
                        .font(.system(size: 14))
                        .focused($focused)
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .seeliCard(.seeliCard, radius: 12, border: false)
                    Button { send(to: c) } label: {
                        if sending { ProgressView().tint(.white).frame(width: 36, height: 36) }
                        else { Image(systemName: "arrow.up").font(.system(size: 14, weight: .semibold)).frame(width: 36, height: 36) }
                    }
                    .foregroundStyle(.white)
                    .background(Circle().fill(Color.seeliGreen.opacity(canSend ? 1 : 0.4)))
                    .disabled(!canSend)
                }
                .padding(.leading, 42)
            } else if let answer = c.reply {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(t("comments.reply.yours")).font(.system(size: 11)).foregroundStyle(Color.seeliMuted)
                        Spacer()
                        Button(t("comments.reply.edit")) { startReply(c) }
                            .font(.system(size: 11, weight: .medium)).foregroundStyle(Color.seeliGreen)
                    }
                    Text(answer).font(.system(size: 14)).foregroundStyle(Color.seeliInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .seeliCard(.seeliCard, radius: 12, border: false)
                .padding(.leading, 42)
            } else {
                Button { startReply(c) } label: {
                    Label(t("comments.reply"), systemImage: "arrowshape.turn.up.left")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.seeliGreen)
                }
                .padding(.leading, 42)
            }
        }
        .padding(12)
        .seeliCard(radius: 14)
    }

    private var canSend: Bool { !sending && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private func startReply(_ c: Comment) {
        draft = c.reply ?? ""
        replyingTo = c.id
        focused = true
    }

    private func send(to c: Comment) {
        sending = true
        Task {
            if let r = await store.replyToComment(momentID: moment.id, commentID: c.id, text: draft),
               let i = comments.firstIndex(where: { $0.id == c.id }) {
                comments[i].reply = r.reply
                comments[i].repliedAt = r.repliedAt
                replyingTo = nil
                draft = ""
            }
            sending = false
        }
    }
}
