import SwiftUI

/// "What's new" — shown once after updating to a version with notable changes.
enum WhatsNew {
    /// Bump when there is a new list to show.
    static let current = "1.3"
    private static let key = "seeli.whatsNewSeen"

    static var isPending: Bool { UserDefaults.standard.string(forKey: key) != current }
    static func markSeen() { UserDefaults.standard.set(current, forKey: key) }

    struct Item: Identifiable { var id: String; var icon: String }
    static let items: [Item] = [
        Item(id: "comments", icon: "bubble.left.and.bubble.right"),
        Item(id: "audience", icon: "star"),
        Item(id: "requests", icon: "person.badge.plus"),
        Item(id: "connect", icon: "person.2"),
        Item(id: "once", icon: "eye"),
        Item(id: "dark", icon: "moon"),
        Item(id: "gestures", icon: "hand.draw"),
    ]
}

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        EyeLogo(size: 28, color: .seeliGreen)
                        Text(t("whatsnew.title")).font(.system(size: 30, weight: .semibold)).foregroundStyle(Color.seeliInk)
                        Text(t("whatsnew.subtitle")).font(.system(size: 14)).foregroundStyle(Color.seeliMuted)
                    }
                    .padding(.top, 36)
                    .padding(.bottom, 6)
                    ForEach(WhatsNew.items) { item in
                        HStack(alignment: .top, spacing: 16) {
                            Circle().fill(Color.seeliCard).frame(width: 44, height: 44)
                                .overlay(Image(systemName: item.icon).font(.system(size: 18)).foregroundStyle(Color.seeliGreen))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(t("whatsnew.\(item.id).title")).font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.seeliInk)
                                Text(t("whatsnew.\(item.id).body")).font(.system(size: 14)).foregroundStyle(Color.seeliMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 20)
            }
            Button(t("whatsnew.done")) { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
        .background(Color.seeliBG.ignoresSafeArea())
        .onDisappear { WhatsNew.markSeen() }
    }
}
