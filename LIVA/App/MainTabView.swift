import SwiftUI

/// Hosts the four primary destinations behind the custom dark pill tab bar
/// from the product mockups.
struct MainTabView: View {
    enum Tab: CaseIterable {
        case loops, health, groups, profile

        var title: String {
            switch self {
            case .loops: return "LOOPS"
            case .health: return "HEALTH"
            case .groups: return "GROUPS"
            case .profile: return "PROFILE"
            }
        }
        var symbol: String {
            switch self {
            case .loops: return "square.on.square"
            case .health: return "waveform.path.ecg"
            case .groups: return "person.3"
            case .profile: return "person"
            }
        }
    }

    @State private var selection: Tab = .health

    var body: some View {
        ZStack(alignment: .bottom) {
            LivaBackground()

            Group {
                switch selection {
                case .loops:   NavigationStack { FeedView() }
                case .health:  NavigationStack { HealthDashboardView() }
                case .groups:  NavigationStack { GroupsView() }
                case .profile: NavigationStack { ProfileView() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            tabBar
        }
        .ignoresSafeArea(.keyboard)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                let isActive = selection == tab
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { selection = tab }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 19, weight: isActive ? .semibold : .regular))
                        Text(tab.title)
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.6)
                    }
                    .foregroundStyle(isActive ? Theme.Palette.tabBarText : Theme.Palette.tabBarMuted)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.pill, style: .continuous)
                .fill(Theme.Palette.tabBar)
                .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }
}

/// Lightweight placeholder for the Groups destination (full community features
/// are part of the post-MVP roadmap).
struct GroupsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                BrandHeader(secondary: "groups")
                EmptyStateView(
                    systemName: "person.3.fill",
                    title: "Communities are coming",
                    message: "Groups will let you train alongside your gym, your crew, and creators you follow. Part of the next LIVA release."
                )
            }
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .background(LivaBackground())
        .navigationBarHidden(true)
    }
}
