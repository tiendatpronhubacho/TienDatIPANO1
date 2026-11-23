import SwiftUI
import UIKit

struct ContentView3106: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var patchStore: PatchProjectStore
    @EnvironmentObject private var repositoryStore: PackageRepositoryStore
    @State private var tabNavigation: AppTabNavigationState
    @State private var showSettings = false
    @State private var showLogs = false
    @State private var showAppGroupAlert = false
    @StateObject private var scanCoordinator = ScanCoordinator()
    @EnvironmentObject private var appState: AppState

    init() {
#if targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        let initialTab: Int
        if arguments.contains("--simulate-new-tab")
            || arguments.contains("--simulate-sources-tab")
            || arguments.contains("--simulate-installed-tab")
            || arguments.contains("--simulate-patch-tab")
            || arguments.contains("--simulate-features-tab") {
            initialTab = 0
        } else if arguments.contains("--simulate-files-tab") {
            initialTab = 4
        } else if arguments.contains("--simulate-search-tab") {
            initialTab = 5
        } else if arguments.contains("--simulate-cleaner-tab") {
            initialTab = 6
        } else if arguments.contains("--simulate-wallpaper-tab") {
            initialTab = 7
        } else {
            initialTab = 0
        }
        _tabNavigation = State(initialValue: AppTabNavigationState(selectedTab: initialTab))
        _showSettings = State(
            initialValue: arguments.contains("--simulate-settings")
        )
#else
        _tabNavigation = State(initialValue: AppTabNavigationState())
#endif
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                regularLayout
            } else {
                compactLayout
            }
        }
        .tint(AppTheme.accent)
        .imageScale(.small)
        .onChange(of: patchDraftCoordinator.request?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.installed.rawValue) }
        }
        .onChange(of: patchDraftCoordinator.importRequest?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.installed.rawValue) }
        }
        .onAppear {
            tabNavigation.reconcileSelection(with: featureVisibility)
#if !targetEnvironment(simulator)
            if SandboxAccess.needsWorseQuery, SandboxAccess.appGroup == nil {
                showAppGroupAlert = true
            }
#endif
        }
        .alert(language.text("appgroup.title"), isPresented: $showAppGroupAlert) {
            Button(language.text("common.ok")) {}
        } message: {
            Text(language.text("appgroup.message"))
        }
        .environmentObject(scanCoordinator)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showLogs) { LogView() }
        .sheet(isPresented: $scanCoordinator.isPresented) {
            ScanProgressSheet()
                .environmentObject(scanCoordinator)
                .environment(\.appLanguage, language)
        }
        .overlay(alignment: .bottom) {
            if scanCoordinator.isRunning && !scanCoordinator.isPresented {
                ScanRunningBanner()
                    .environmentObject(scanCoordinator)
                    .environment(\.appLanguage, language)
            }
        }
        .overlay(alignment: .top) {
            // Kernel devices need a ran-once-per-launch unlock. The banner is
            // top-aligned so it reads before any list content, and only shows
            // while the chain has not succeeded — a settled failure stays
            // visible through the Unlock screen rather than nagging here.
            if appState.needsUnlock {
                NavigationLink {
                    UnlockView()
                } label: {
                    UnlockBanner()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.top, 6)
            }
        }
        .patchStorePresentation(patchStore)
        .repositoryStorePresentation(repositoryStore, patchStore: patchStore)
    }

    private var compactLayout: some View {
        TabView(selection: tabSelection) {
            ForEach(featureVisibility.visibleSections) { section in
                sectionContent(section)
                    .tabItem {
                        CompactTabLabel(
                            title: language.text(section.titleKey),
                            systemImage: section.systemImage
                        )
                    }
                    .tag(section.rawValue)
            }
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List {
                ForEach(featureVisibility.visibleSections) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            tabNavigation.select(section.rawValue)
                        }
                    } label: {
                        Label(language.text(section.titleKey), systemImage: section.systemImage)
                            .fontWeight(section.rawValue == tabNavigation.selectedTab ? .semibold : .regular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        section.rawValue == tabNavigation.selectedTab
                            ? AppTheme.accent.opacity(0.14)
                            : Color.clear
                    )
                    .accessibilityAddTraits(
                        section.rawValue == tabNavigation.selectedTab ? .isSelected : []
                    )
                }
            }
            .navigationTitle("3106")
            .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
        } detail: {
            sectionContent(selectedVisibleSection)
                .id(selectedVisibleSection.rawValue)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func sectionContent(_ section: AppSection) -> some View {
        switch section {
        case .home:
            FeatureHubView(
                onSelectTab: { section in
                    tabNavigation.select(section.rawValue)
                },
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .new:
            RepositoryNewView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .sources:
            RepositorySourcesView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .installed:
            PatchProjectsView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .files:
            AppDataBrowserView(
                tabSession: filesTabSession,
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .search:
            RepositorySearchView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .cleaner:
            CleanerView(onOpenSettings: openSettings)
        case .backup:
            BackupTabView()
        case .wallpapers:
            WallpaperLabView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        }
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { tabNavigation.selectedTab },
            set: { tabNavigation.select($0) }
        )
    }

    private var filesTabSession: Binding<FilesTabSession> {
        Binding(
            get: { tabNavigation.filesTabs },
            set: { tabNavigation.setFilesTabs($0) }
        )
    }

    private var featureVisibility: FeatureVisibility {
        FeatureVisibility(
            selectedSections: [.home, .files, .search, .cleaner, .wallpapers],
            wallpapersSupported: WallpaperFeatureSupportPolicy.isSupported(
                major: AppInfo.versionTuple.major
            ),
            developerModeEnabled: true
        )
    }

    private var selectedVisibleSection: AppSection {
        let selected = AppSection(rawValue: tabNavigation.selectedTab)
        return selected.flatMap {
            featureVisibility.isVisible($0) ? $0 : nil
        } ?? .home
    }

    private func openSettings() {
        showSettings = true
    }

    private func openLogs() {
        showLogs = true
    }
}

private struct CompactTabLabel: View {
    let title: String
    let systemImage: String

    @ViewBuilder
    var body: some View {
        if let image = UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        )?.withRenderingMode(.alwaysTemplate) {
            Image(uiImage: image)
        } else {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
        }
        Text(title)
    }
}



// MARK: - TIENDAT PRESENTATION SHELL
private func configureTienDatTabBar() {
    let appearance = UITabBarAppearance()
    appearance.configureWithOpaqueBackground()
    appearance.backgroundColor = .black
    let item = UITabBarItemAppearance()
    item.normal.iconColor = UIColor.white.withAlphaComponent(0.5)
    item.normal.titleTextAttributes = [.foregroundColor: UIColor.white.withAlphaComponent(0.5)]
    item.selected.iconColor = .white
    item.selected.titleTextAttributes = [.foregroundColor: UIColor.white]
    appearance.stackedLayoutAppearance = item
    appearance.inlineLayoutAppearance = item
    appearance.compactInlineLayoutAppearance = item
    UITabBar.appearance().standardAppearance = appearance
    if #available(iOS 15.0, *) { UITabBar.appearance().scrollEdgeAppearance = appearance }
}

private func loadTienDatImage(named name: String) -> Image {
    if let url = Bundle.main.url(forResource: name, withExtension: "jpg"),
       let image = UIImage(contentsOfFile: url.path) { return Image(uiImage: image) }
    if let image = UIImage(named: name) { return Image(uiImage: image) }
    return Image(systemName: "photo")
}

struct ContentView: View {
    @State private var selectedTab = 0
    var body: some View {
        TabView(selection: $selectedTab) {
            TienDatHomeView()
                .tabItem { Label("Trang chủ", systemImage: "house.fill") }
                .tag(0)
            ContentView3106()
                .tabItem { Label("Chức năng", systemImage: "cube.fill") }
                .tag(1)
            SettingsView()
                .tabItem { Label("Cài đặt", systemImage: "gearshape.fill") }
                .tag(2)
        }
        .tint(.white)
        .preferredColorScheme(.dark)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(Color.black, for: .tabBar)
        .onAppear { configureTienDatTabBar() }
    }
}

struct TienDatHomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var homeScanCoordinator = ScanCoordinator()
    @State private var showCleaner = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            GeometryReader { proxy in
                loadTienDatImage(named: "background_home")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
            .ignoresSafeArea()
            
            Color.black.opacity(0.2).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    brandHeader
                    devicePanel
                    gameLaunchPanel
                    footerStatus
                    developerCredits
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }
        .sheet(isPresented: $showCleaner) {
            CleanerView(onOpenSettings: {})
                .environmentObject(homeScanCoordinator)
        }
    }

    private var brandHeader: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("TIENDAT")
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(.white)
                Text("PATCH CONTROL CENTER")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.7)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
        }
    }

    private var devicePanel: some View {
        VStack(spacing: 0) {
            panelTitle("DEVICE STATUS", icon: "shield.lefthalf.filled")
            statusRow(icon: "apple.logo", title: "iOS", value: AppInfo.osVersion, color: .white)
            statusRow(icon: "iphone", title: "Device", value: AppInfo.displayMachineName, color: .white)
            statusRow(icon: "checkmark.seal.fill", title: "Support", value: appState.isSupported ? "SUPPORTED" : "UNSUPPORTED", color: appState.isSupported ? .green : .red)
        }
        .padding(16)
        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.3), lineWidth: 0.5))
    }

    private var gameLaunchPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            panelTitle("LAUNCH GAME", icon: "arrow.up.forward.app.fill")
            HStack(spacing: 12) {
                launchButton(title: "Free Fire VN", subtitle: "com.garena.ffvn", color: .white, scheme: "freefirevn")
            }
            Button {
                showCleaner = true
            } label: {
                Label("Clean Cache & Temp", systemImage: "trash.slash.fill")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.3), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
    }

    private var footerStatus: some View {
        HStack(spacing: 10) {
            Circle().fill(.green).frame(width: 9, height: 9).shadow(color: .green, radius: 6)
            Text("SISTEMA PRONTO")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.72))
            Spacer()
            Text("TIENDAT • PRONTO")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Color.white.opacity(0.1), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
    }

    private var developerCredits: some View {
        VStack(spacing: 10) {
            Text("Developed by TienDat")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
            Text("Zalo TienDat")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            HStack(spacing: 10) {
                channelButton(title: "Zalo", url: "https://zalo.me/0986321175")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private func channelButton(title: String, url: String) -> some View {
        Button {
            guard let destination = URL(string: url) else { return }
            UIApplication.shared.open(destination)
        } label: {
            Label(title, systemImage: "paperplane.fill")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.white.opacity(0.1), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func panelTitle(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 12, weight: .black, design: .rounded))
            .tracking(1.4)
            .foregroundStyle(.white)
    }

    private func statusRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 17, weight: .bold)).foregroundStyle(color).frame(width: 24)
            Text(title).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.58))
            Spacer()
            Text(value).font(.system(size: 14, weight: .black, design: .rounded)).foregroundStyle(.white)
        }
        .padding(.top, 14)
    }

    private func launchButton(title: String, subtitle: String, color: Color, scheme: String) -> some View {
        Button { openGame(scheme: scheme) } label: {
            VStack(alignment: .leading, spacing: 7) {
                Image(systemName: "arrow.up.right.square.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
            .padding(.horizontal, 14)
            .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.3), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func openGame(scheme: String) {
        guard let url = URL(string: "\(scheme)://") else { return }
        UIApplication.shared.open(url, options: [:]) { success in
            print("launch: \(scheme) success=\(success)")
        }
    }
}

