import SwiftUI

/// A moment's comments, shared by its owner and everyone who can see it.
/// Each comment says who sees it: only the photo's owner, or the whole audience
/// (after the owner approves it). Anyone can comment many times and reply.
struct CommentThreadSheet: View {
    @Environment(AppStore.self) private var store
    var momentID: String
    var ownerID: String
    var ownerName: String
    var note: String

    @State private var thread: CommentThread?
    @State private var loading = true
    @State private var draft = ""
    @State private var replyTo: ThreadComment?
    @State private var editing: ThreadComment?
    @State private var visibility: ThreadComment.Visibility = .owner
    @State private var sending = false
    @State private var confirmDelete: ThreadComment?
    @FocusState private var focused: Bool

    private var isOwner: Bool { thread?.isOwner ?? false }
    private var comments: [ThreadComment] { thread?.comments ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Color.seeliLine)
            if loading {
                Spacer(); ProgressView(); Spacer()
            } else if comments.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 26, weight: .light))
                    Text(isOwner ? t("comments.empty") : t("thread.empty"))
                        .multilineTextAlignment(.center)
                }
                .font(.system(size: 13))
                .foregroundStyle(Color.seeliMuted)
                .padding(.horizontal, 30)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            ForEach(groups, id: \.top.id) { group in
                                VStack(alignment: .leading, spacing: 10) {
                                    row(group.top, isReply: false)
                                    ForEach(group.replies) { r in
                                        row(r, isReply: true).padding(.leading, 38)
                                    }
                                }
                                .id(group.top.id)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .onChange(of: comments.count) { _, _ in
                        if let last = groups.last { withAnimation { proxy.scrollTo(last.top.id, anchor: .bottom) } }
                    }
                }
            }
            composer
        }
        .background(Color.seeliBG.ignoresSafeArea())
        .task { await load() }
        .confirmationDialog(t("thread.delete.confirm"),
                            isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }),
                            titleVisibility: .visible) {
            Button(t("common.delete"), role: .destructive) {
                if let c = confirmDelete {
                    Task {
                        if await store.deleteComment(momentID: momentID, commentID: c.id) { await load() }
                    }
                }
                confirmDelete = nil
            }
            Button(t("common.cancel"), role: .cancel) { confirmDelete = nil }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(t("comments.title")).font(.system(size: 18, weight: .semibold)).foregroundStyle(Color.seeliInk)
            if !note.isEmpty {
                Text(note).font(SeeliFont.mincho(13)).foregroundStyle(Color.seeliMuted).lineLimit(2)
            }
            Text(isOwner ? t("thread.owner.hint") : tf("thread.friend.hint", ownerName))
                .font(.system(size: 11)).foregroundStyle(Color.seeliMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 12)
    }

    // MARK: Rows

    private struct ThreadGroup { var top: ThreadComment; var replies: [ThreadComment] }

    /// Top-level comments, each followed by every answer below it (one level of indent).
    private var groups: [ThreadGroup] {
        let byID = Dictionary(uniqueKeysWithValues: comments.map { ($0.id, $0) })
        func root(_ c: ThreadComment) -> String {
            var cur = c
            var guardCount = 0
            while let p = cur.parentId, let parent = byID[p], guardCount < 50 { cur = parent; guardCount += 1 }
            return cur.id
        }
        var order: [String] = []
        var replies: [String: [ThreadComment]] = [:]
        for c in comments {
            let r = root(c)
            if r == c.id { order.append(c.id) } else { replies[r, default: []].append(c) }
        }
        return order.compactMap { id in byID[id].map { ThreadGroup(top: $0, replies: replies[id] ?? []) } }
    }

    private func parentName(_ c: ThreadComment) -> String? {
        guard let p = c.parentId else { return nil }
        return comments.first { $0.id == p }?.author.name
    }

    @ViewBuilder
    private func row(_ c: ThreadComment, isReply: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Avatar(initial: c.author.initial, size: isReply ? 26 : 32)
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(c.mine ? t("thread.you") : c.author.name)
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.seeliInk)
                        if isReply, let to = parentName(c) {
                            Label(to, systemImage: "arrowshape.turn.up.left")
                                .font(.system(size: 10)).foregroundStyle(Color.seeliMuted).lineLimit(1)
                        }
                    }
                    Text(c.text).font(.system(size: 14)).foregroundStyle(Color.seeliInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(c.mine ? Color.seeliGreenPale.opacity(0.45) : Color.seeliSurface))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(c.isPending ? Color.seeliSun : .clear, lineWidth: 1.2))
                .contentShape(Rectangle())
                .onTapGesture { startReply(c) }

                HStack(spacing: 14) {
                    Text(ago(c.createdAt) + (c.editedAt != nil ? " · " + t("thread.edited") : ""))
                        .lineLimit(1).fixedSize()
                    badge(c)
                    Button(t("comments.reply")) { startReply(c) }.foregroundStyle(Color.seeliGreen)
                    if c.mine { Button(t("comments.reply.edit")) { startEdit(c) } }
                    if c.mine || isOwner { Button(t("common.delete")) { confirmDelete = c } }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.seeliMuted)

                if isOwner && c.isPending && !c.mine {
                    HStack(spacing: 8) {
                        Button { approve(c, true) } label: {
                            Label(t("thread.approve"), systemImage: "checkmark")
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Capsule().fill(Color.seeliGreen)).foregroundStyle(.white)
                        }
                        Button { approve(c, false) } label: {
                            Text(t("thread.keepPrivate"))
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Capsule().fill(Color.seeliCard)).foregroundStyle(Color.seeliInk)
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
                }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func badge(_ c: ThreadComment) -> some View {
        if c.author.id == ownerID {
            // The owner's comments are public, except answers to a private comment.
            if let p = c.parentId, let parent = comments.first(where: { $0.id == p }), !isPublic(parent) {
                Label(t("thread.private.reply"), systemImage: "lock")
            }
        } else if c.isPending {
            Label(t("thread.pending"), systemImage: "hourglass").foregroundStyle(Color(hex: 0xA07A2C))
        } else if c.visibility == .owner || c.status == .rejected {
            Label(isOwner ? t("thread.private.owner") : tf("thread.private", ownerName), systemImage: "lock")
        } else {
            Label(t("thread.public"), systemImage: "person.2")
        }
    }

    private func isPublic(_ c: ThreadComment) -> Bool {
        c.author.id == ownerID || (c.visibility == .circle && c.status == .approved)
    }

    // MARK: Composer

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let editing {
                chip(t("thread.editing"), systemImage: "pencil") { self.editing = nil; draft = "" }
                    .accessibilityLabel(editing.text)
            } else if let replyTo {
                chip(tf("thread.replyingTo", replyTo.mine ? t("thread.you") : replyTo.author.name),
                     systemImage: "arrowshape.turn.up.left") { self.replyTo = nil }
            }
            if !isOwner && editing == nil {
                HStack(spacing: 8) {
                    visibilityOption(.owner, title: tf("thread.only", ownerName), icon: "lock")
                    visibilityOption(.circle, title: t("thread.circle"), icon: "person.2")
                }
                if visibility == .circle {
                    Text(tf("thread.circle.hint", ownerName)).font(.system(size: 11)).foregroundStyle(Color.seeliMuted)
                }
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField(t("connect.comment.placeholder"), text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .font(.system(size: 15))
                    .focused($focused)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .seeliCard(radius: 18)
                Button(action: send) {
                    Group {
                        if sending { ProgressView().tint(.white) }
                        else { Image(systemName: "arrow.up").font(.system(size: 15, weight: .semibold)) }
                    }
                    .frame(width: 40, height: 40)
                    .foregroundStyle(.white)
                    .background(Circle().fill(Color.seeliGreen.opacity(canSend ? 1 : 0.4)))
                }
                .disabled(!canSend)
                .accessibilityLabel(t("comments.reply.send"))
            }
            if let error = store.lastError, !sending {
                Text(error).font(.system(size: 12)).foregroundStyle(Color(hex: 0xB0574A))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(Color.seeliBG)
        .overlay(alignment: .top) { Divider().overlay(Color.seeliLine) }
    }

    private func visibilityOption(_ v: ThreadComment.Visibility, title: String, icon: String) -> some View {
        Button { visibility = v } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(visibility == v ? Color.seeliGreen : Color.seeliCard))
                .foregroundStyle(visibility == v ? .white : Color.seeliInk)
        }
    }

    private func chip(_ text: String, systemImage: String, onClear: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Label(text, systemImage: systemImage).lineLimit(1)
            Spacer()
            Button(action: onClear) { Image(systemName: "xmark.circle.fill") }
                .accessibilityLabel(t("common.cancel"))
        }
        .font(.system(size: 12))
        .foregroundStyle(Color.seeliMuted)
    }

    private var canSend: Bool { !sending && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private func startReply(_ c: ThreadComment) {
        editing = nil
        replyTo = c
        focused = true
    }

    private func startEdit(_ c: ThreadComment) {
        replyTo = nil
        editing = c
        draft = c.text
        focused = true
    }

    private func send() {
        sending = true
        Task {
            if let editing {
                if await store.editComment(momentID: momentID, commentID: editing.id, text: draft) != nil {
                    self.editing = nil
                    draft = ""
                    await load()
                }
            } else if await store.postComment(momentID: momentID, text: draft, parentID: replyTo?.id,
                                              visibility: visibility) != nil {
                draft = ""
                replyTo = nil
                visibility = .owner // each comment starts private; sharing is a deliberate choice
                await load()
            }
            sending = false
        }
    }

    private func approve(_ c: ThreadComment, _ yes: Bool) {
        Task { if await store.approveComment(momentID: momentID, commentID: c.id, approve: yes) { await load() } }
    }

    private func load() async {
        if let th = await store.thread(for: momentID) { thread = th }
        loading = false
    }

    private func ago(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = L10n.shared.language.locale
        f.unitsStyle = .short
        // The server clock may run a second ahead: never say "in 0 seconds".
        let now = Date()
        return f.localizedString(for: min(date, now.addingTimeInterval(-1)), relativeTo: now)
    }
}
