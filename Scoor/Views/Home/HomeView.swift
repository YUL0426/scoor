import SwiftUI

/// Home is the shared day feed; personal scores live in My Page.
struct HomeView: View {
    @EnvironmentObject private var appServices: AppServices
    var onRequestScoreSheet: () -> Void
    var onOpenProfile: () -> Void = {}

    var body: some View {
        FeedView(
            socialService: appServices.socialService,
            feedService: appServices.feedService,
            onRequestScoreSheet: onRequestScoreSheet,
            onOpenProfile: onOpenProfile
        )
    }
}

#Preview {
    HomeView(onRequestScoreSheet: {})
        .environmentObject(AppServices())
}
