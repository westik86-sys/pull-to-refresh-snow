//
//  TestInAppView.swift
//  ProductAvatarPicker
//
//  Экран "Главная".
//

import SwiftUI
import UIKit

struct TestInAppView: View {
    // Остров
    @StateObject private var ncViewModel = NotificationCenterViewModel()
    @State private var staticCloseButtonOpacity: CGFloat = 0
    @State private var staticCloseButtonOffsetY: CGFloat = -18
    @State private var tapExpandProgress: CGFloat = 0
    @State private var isTapClosing: Bool = false
    @State private var tapCloseProgress: CGFloat = 0
    @State private var isOpeningByIslandTap: Bool = false
    @State private var isClosingByCloseButtonTap: Bool = false
    // Главная
    @State private var mainScrollOffset: CGFloat = 0
    @State private var isSystemSearchPresented: Bool = false
    @State private var focusedAccountIndex: Int = 0
    @State private var focusAccountDragOffset: CGFloat = 0
    @State private var isFocusAccountPagerVisible: Bool = false
    @State private var focusAccountDotsHideTask: Task<Void, Never>?
    @State private var homeMainDisplayMode: Home8MainDisplayMode = .focus
    @State private var areHomeKopecksHidden: Bool = true
    @State private var homeVisibleAccountIDs: [String] = Home8FocusAccount.defaultVisibleAccountIDs
    @State private var homeAccountAppearances: [String: HomeAccountCompactAppearance] = [:]
    @State private var homeAccountTitleOverrides: [String: String] = [:]
    @State private var editingCompactAppearanceAccountID: String?
    @State private var compactAccountsPageIndex: Int = 0
    @State private var compactAccountsDragOffset: CGFloat = 0
    @State private var isHomeAccountsHorizontalSwipeActive: Bool = false
    @State private var isRecentFolderPresented: Bool = false
    @State private var recentFolderAnimationProgress: CGFloat = 0
    @State private var systemSearchQuery: String = ""
    @State private var selectedTab: Home8Tab = .main
    @State private var isHomeNavigationTransitionActive: Bool = false
    // Pull-to-refresh
    @State private var mainPullDistance: CGFloat = 0
    @State private var isMainRefreshing: Bool = false
    @State private var isMainDragTracking: Bool = false
    @State private var visibleTitleText: String = "Все уведомления"
    @State private var titleOpacity: CGFloat = 1
    @State private var titleSwapTask: Task<Void, Never>?
    @State private var snowOverlayID: UUID?
    @State private var isSnowSettingsPresented: Bool = false
    @State private var snowEffectSettings: SnowEffectSettings = .persisted

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private let swipeGapHeight: CGFloat = 8
    private let tapExpandAnimation = Animation.timingCurve(0.34, 1.15, 0.25, 1.0, duration: 0.8)
    private let tapCollapseAnimation = Animation.timingCurve(0.34, 1.15, 0.25, 1.0, duration: 0.8)
    private let closeButtonHideDuration: Double = 0.14
    private let closeButtonOpenStartOffset: CGFloat = -18
    private let collapsedLabelTapCloseStart: CGFloat = 0.8
    private let collapsedLabelTapCloseEnd: CGFloat = 1.0
    // Pull-to-refresh constants
    private let mainRefreshThreshold: CGFloat = 56
    private let mainPullResistance: CGFloat = 0.6
    private let mainPullMaxDistance: CGFloat = 64
    private let mainDeadZoneHeight: CGFloat = 16
    private let defaultCollapsedTitle = "Все уведомления"
    private let refreshingCollapsedTitle = "Обновляем ссаные копейки"
    private let titleFadeOutDuration: Double = 0.09
    private let titleFadeInDuration: Double = 0.22
    private let titleSwapDelay: UInt64 = 10_000_000
    private let titleDimmedOpacity: CGFloat = 0.25
    var body: some View {
        GeometryReader { rootGeometry in
            ZStack {
                TabView(selection: $selectedTab) {
                    home8MainTab
                        .tag(Home8Tab.main)
                        .tabItem {
                            Label(Home8Tab.main.title, systemImage: Home8Tab.main.symbolName)
                        }

                    home8StubTab(.payments)
                        .tag(Home8Tab.payments)
                        .tabItem {
                            Label(Home8Tab.payments.title, systemImage: Home8Tab.payments.symbolName)
                        }

                    home8StubTab(.city)
                        .tag(Home8Tab.city)
                        .tabItem {
                            Label(Home8Tab.city.title, systemImage: Home8Tab.city.symbolName)
                        }

                    home8StubTab(.chat)
                        .tag(Home8Tab.chat)
                        .tabItem {
                            Label(Home8Tab.chat.title, systemImage: Home8Tab.chat.symbolName)
                        }

                    home8StubTab(.showcase)
                        .tag(Home8Tab.showcase)
                        .tabItem {
                            Label(Home8Tab.showcase.title, systemImage: Home8Tab.showcase.symbolName)
                        }
                }
                .tint(Color(hex: "0A84FF"))

                homeRecentFolderOverlay(screenSize: rootGeometry.size)
                    .opacity(recentFolderAnimationProgress > 0 ? 1 : 0)
                    .allowsHitTesting(isRecentFolderPresented)
                    .zIndex(10)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                isSnowSettingsPresented = true
            }
        )
        .sheet(isPresented: $isSystemSearchPresented) {
            Home8SystemSearchView(searchText: $systemSearchQuery)
        }
        .sheet(isPresented: $isSnowSettingsPresented) {
            SnowSettingsSheet(snowSettings: $snowEffectSettings)
                .presentationDetents([.height(620), .large])
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .height(620)))
        }
        .sheet(isPresented: compactAppearanceEditorPresented) {
            if let account = editingCompactAppearanceAccount {
                NavigationStack {
                    HomeCompactAccountAppearanceEditorView(
                        account: account,
                        accountName: accountNameBinding(for: account),
                        appearance: compactAppearanceBinding(for: account)
                    )
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .onChange(of: snowEffectSettings) { _, newSettings in
            newSettings.persist()
        }
    }

    private let collapsedIslandBaseHeight: CGFloat = 108

    // MARK: - Main tab (остров + контент)

    private var home8MainTab: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let screenWidth = geometry.size.width
            let contentH = ncViewModel.contentHeight(screenHeight: screenHeight)
            let contentCenterY = ncViewModel.contentY(screenHeight: screenHeight) + contentH / 2
            // mainScrollOffset: 0 вверху, уходит в минус при скроле вниз, положительный при bounce
            let islandScrollShift: CGFloat = ncViewModel.isExpanded ? 0 : mainScrollOffset
            let bounceShift: CGFloat = max(0, mainScrollOffset) // положительная часть = bounce
            let islandVisible = mainScrollOffset > -collapsedIslandBaseHeight
            let spinnerBaseY = geometry.safeAreaInsets.top + 64
            let currentIslandHeight = ncViewModel.islandHeight(screenHeight: screenHeight)

            ZStack(alignment: .top) {
                // Базовый фон экрана: в темной теме под градиентом должен быть
                // чистый черный, чтобы "Главная" плавно уходила из цвета острова.
                screenBackgroundColor
                    .ignoresSafeArea()

                refreshPullBackdropColor
                    .frame(
                        width: screenWidth,
                        height: currentIslandHeight + mainPullMaxDistance + geometry.safeAreaInsets.top
                    )
                    .ignoresSafeArea(edges: .top)
                    .opacity(isRefreshSpinnerVisible ? 1 : 0)
                    .allowsHitTesting(false)

                // Внутренний ZStack — двигается ЦЕЛИКОМ при pull
                ZStack(alignment: .top) {
                    // Статический фон контента (страхует от зазоров при скролле)
                    contentBackgroundSurface
                        .frame(width: screenWidth, height: contentH)
                        .position(x: screenWidth / 2, y: contentCenterY + bounceShift)
                        .zIndex(0)

                    // Чёрный разделитель — ТОЛЬКО зона gap + скругления (72px).
                    // За контентом уже лежит фон главной (zIndex 0), поэтому
                    // у краёв показывается актуальная подложка темы.
                    Color.black
                        .frame(width: screenWidth, height: 32 + swipeGapHeight + 32)
                        .position(
                            x: screenWidth / 2,
                            y: ncViewModel.islandHeight(screenHeight: screenHeight)
                                - 32 + (32 + swipeGapHeight + 32) / 2
                                + islandScrollShift
                        )
                        .opacity(ncViewModel.isExpanded ? 0 : 1)
                        .zIndex(0.5)

                    // ScrollView (scrollClipDisabled: контент выходит за фрейм при скроле)
                    homeScrollView
                        .scrollClipDisabled(true)
                        .frame(width: screenWidth, height: contentH)
                        .position(x: screenWidth / 2, y: contentCenterY)
                        .scrollDisabled(
                            ncViewModel.isExpanded
                                || isMainDragTracking
                                || isMainRefreshing
                                || isHomeAccountsHorizontalSwipeActive
                                || isRecentFolderPresented
                        )
                        .overlay {
                            if ncViewModel.isExpanded {
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture { ncViewModel.toggleExpanded() }
                            }
                        }
                        .zIndex(1)

                    // Остров — смещается со скролом
                    islandView(screenHeight: screenHeight)
                        .frame(height: ncViewModel.islandHeight(screenHeight: screenHeight))
                        .position(
                            x: screenWidth / 2,
                            y: ncViewModel.islandHeight(screenHeight: screenHeight) / 2
                                + islandScrollShift
                        )
                        .allowsHitTesting(islandVisible)
                        .zIndex(2)
                }
                .offset(y: mainPullDistance)

                // Спиннер (фиксирован вверху, чуть двигается с pull)
                Home8RefreshSpinner(isAnimating: isRefreshSpinnerVisible)
                    .opacity(isRefreshSpinnerVisible ? 1 : 0)
                    .position(
                        x: screenWidth / 2,
                        y: spinnerBaseY + min(max(mainPullDistance * 0.25, 0), 28)
                    )
                    .zIndex(3)

                let snowOverlayHeight = screenHeight * snowEffectSettings.overlayHeightPercent / 100
                SnowOverlay(triggerID: snowOverlayID, settings: snowEffectSettings) {
                    self.snowOverlayID = nil
                }
                .frame(width: screenWidth, height: snowOverlayHeight)
                .position(x: screenWidth / 2, y: snowOverlayHeight / 2)
                .allowsHitTesting(false)
                .zIndex(4)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        guard !isRecentFolderPresented else { return }
                        handleMainPullChanged(value)
                    }
                    .onEnded { value in
                        guard !isRecentFolderPresented else { return }
                        handleMainPullEnded(value)
                    }
            )
        }
        .ignoresSafeArea()
        .onAppear {
            isHomeNavigationTransitionActive = false
            if ncViewModel.isExpanded {
                syncCloseButtonOpacity(for: true)
            } else {
                staticCloseButtonOpacity = 0
                staticCloseButtonOffsetY = 0
                tapExpandProgress = 0
                isTapClosing = false
                tapCloseProgress = 0
            }
        }
        .onChange(of: ncViewModel.isExpanded) { _, expanded in
            syncCloseButtonOpacity(for: expanded)
        }
        .onChange(of: isRefreshSpinnerVisible) { _, _ in
            animateCollapsedTitleChange()
        }
        .onChange(of: homeVisibleAccountIDs) { _, _ in
            clampHomeAccountsNavigationState()
        }
        .onChange(of: homeMainDisplayMode) { _, _ in
            clampHomeAccountsNavigationState()
            focusAccountDotsHideTask?.cancel()
            focusAccountDotsHideTask = nil
            isFocusAccountPagerVisible = false
            focusAccountDragOffset = 0
            compactAccountsDragOffset = 0
            isHomeAccountsHorizontalSwipeActive = false
        }
        .onChange(of: compactAccountsPageIndex) { _, _ in
            guard homeMainDisplayMode == .compact else { return }
            showFocusAccountDots()
            scheduleFocusAccountDotsHide()
        }
        .onDisappear {
            focusAccountDotsHideTask?.cancel()
            focusAccountDotsHideTask = nil
        }
        .toolbar(ncViewModel.isExpanded ? .hidden : .visible, for: .tabBar)
        .animation(.easeInOut(duration: 0.25), value: ncViewModel.isExpanded)
    }

    // ScrollView с фиксированным фреймом; scrollClipDisabled позволяет контенту
    // выходить за пределы фрейма при скроле (остров на zIndex 2 перекрывает overflow)
    private var homeScrollView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    homeHeaderBar
                    homeAccountsDisplaySection
                    homeQuickActionsSection
                    homeInsightsCardsSection
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, 14)
                .padding(.top, 16)
                .padding(.bottom, 120)
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .background(contentBackgroundSurface)
        }
        .scrollBounceBehavior(.basedOnSize)
        .modifier(Home8ScrollBounceModifier(isBounceEnabled: !isHomeAccountsHorizontalSwipeActive))
        .modifier(Home8ScrollOffsetModifier(
            offset: $mainScrollOffset,
            allowsPositiveOffset: true
        ))
        .refreshable {
            await refreshMainContent()
        }
    }

    // Drag острова разрешён только из зоны острова + gap
    private func canStartOpeningDrag(_ value: DragGesture.Value) -> Bool {
        value.startLocation.y <= collapsedIslandBaseHeight + swipeGapHeight
    }

    // MARK: - Pull-to-refresh

    private var isMainScrollAtTop: Bool {
        mainScrollOffset >= -2
    }

    private var isRefreshSpinnerVisible: Bool {
        mainPullDistance > 6 || isMainRefreshing
    }

    private var collapsedTitleText: String {
        (mainPullDistance > 6 || isMainRefreshing) ? refreshingCollapsedTitle : defaultCollapsedTitle
    }

    private func canStartMainRefreshDrag(_ value: DragGesture.Value) -> Bool {
        guard !ncViewModel.isExpanded else { return false }
        guard !isMainRefreshing else { return false }
        guard !isHomeAccountsHorizontalSwipeActive else { return false }
        guard isVerticalMainPullIntent(value) else { return false }
        guard isMainScrollAtTop else { return false }
        let mainStartY = collapsedIslandBaseHeight + swipeGapHeight + mainDeadZoneHeight
        return value.startLocation.y >= mainStartY
    }

    private func handleMainPullChanged(_ value: DragGesture.Value) {
        if isHomeAccountsHorizontalSwipeActive || isHorizontalHomeAccountSwipe(value) {
            cancelMainPullTracking()
            return
        }
        guard canStartMainRefreshDrag(value) else { return }
        // Флаг ставится ТОЛЬКО при реальном pull-down, не при скролле вверх
        guard value.translation.height > 0 else { return }
        if !isMainDragTracking { isMainDragTracking = true }
        let pulled = min(value.translation.height * mainPullResistance, mainPullMaxDistance)
        mainPullDistance = pulled
    }

    private func handleMainPullEnded(_ value: DragGesture.Value) {
        if isHomeAccountsHorizontalSwipeActive || isHorizontalHomeAccountSwipe(value) {
            cancelMainPullTracking()
            return
        }
        guard isMainDragTracking else { return }
        isMainDragTracking = false

        if mainPullDistance >= mainRefreshThreshold && !isMainRefreshing {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            Task { await refreshMainContent() }
        } else {
            withAnimation(.easeOut(duration: 0.16)) {
                mainPullDistance = 0
            }
        }
    }

    private func cancelMainPullTracking() {
        guard isMainDragTracking || mainPullDistance != 0 else { return }
        isMainDragTracking = false
        withAnimation(.easeOut(duration: 0.12)) {
            mainPullDistance = 0
        }
    }

    private func isHorizontalHomeAccountSwipe(_ value: DragGesture.Value) -> Bool {
        let horizontalDistance = abs(value.translation.width)
        let verticalDistance = abs(value.translation.height)
        return horizontalDistance > max(verticalDistance * 1.18, 8)
    }

    private func isVerticalMainPullIntent(_ value: DragGesture.Value) -> Bool {
        let horizontalDistance = abs(value.translation.width)
        return value.translation.height > max(horizontalDistance * 1.2, 8)
    }

    private func beginHomeNavigationTransition(reason: String) {
        isHomeNavigationTransitionActive = true
    }

    @MainActor
    private func refreshMainContent() async {
        guard !ncViewModel.isExpanded else { return }
        guard !isMainRefreshing else { return }

        isMainRefreshing = true

        do {
            try await Task.sleep(nanoseconds: 700_000_000)
        } catch {
            withAnimation(.easeOut(duration: 0.18)) {
                isMainRefreshing = false
                mainPullDistance = 0
            }
            return
        }

        withAnimation(.easeOut(duration: 0.18)) {
            isMainRefreshing = false
            mainPullDistance = 0
        }
        showSnowOverlayAfterRefresh()
    }

    @MainActor
    private func showSnowOverlayAfterRefresh() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        guard snowEffectSettings.isEnabled else { return }
        snowOverlayID = UUID()
    }

    private func animateCollapsedTitleChange() {
        let newTitle = collapsedTitleText
        titleSwapTask?.cancel()
        titleSwapTask = nil

        guard visibleTitleText != newTitle || titleOpacity != 1 else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            visibleTitleText = newTitle
            titleOpacity = 1
        }
    }

    // MARK: - Island

    private func islandView(screenHeight: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(islandBackgroundColor)

            notificationCenterContent(screenHeight: screenHeight)
                .zIndex(0)

            Text(visibleTitleText)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(primaryTextColor)
                .kerning(-0.24)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .opacity(collapsedTextOpacity(screenHeight: screenHeight) * titleOpacity)

            closeButtonOverlay(screenHeight: screenHeight)
                .zIndex(3)
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    guard !ncViewModel.isExpanded else { return }
                    guard canStartOpeningDrag(value) else { return }
                    ncViewModel.handleDrag(
                        translation: value.translation.height,
                        screenHeight: screenHeight
                    )
                }
                .onEnded { value in
                    guard !ncViewModel.isExpanded else { return }
                    guard canStartOpeningDrag(value) else { return }
                    staticCloseButtonOpacity = ncViewModel.closeButtonOpacity(screenHeight: screenHeight)
                    staticCloseButtonOffsetY = ncViewModel.closeButtonOffsetY(screenHeight: screenHeight)
                    ncViewModel.handleDragEnd(
                        translation: value.translation.height,
                        velocity: value.predictedEndTranslation.height,
                        screenHeight: screenHeight
                    )
                }
        )
        .onTapGesture {
            guard !ncViewModel.isExpanded else { return }
            isOpeningByIslandTap = true
            ncViewModel.toggleExpanded()
        }
    }

    private func notificationCenterContent(screenHeight: CGFloat) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                notificationSection(title: "Важное", cards: importantNotifications)
                notificationSection(title: "Интересное", cards: interestingNotifications)
            }
            .padding(.top, 92)
            .padding(.bottom, 120)
        }
        .opacity(expandedContentOpacity(screenHeight: screenHeight))
        .allowsHitTesting(ncViewModel.isExpanded)
    }

    private func closeButtonOverlay(screenHeight: CGFloat) -> some View {
        VStack {
            Spacer()
            Button(action: {
                guard ncViewModel.isExpanded else { return }
                isClosingByCloseButtonTap = true
                ncViewModel.toggleExpanded()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Закрыть")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(primaryTextColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(closeButtonBackgroundColor)
                .clipShape(Capsule())
            }
            .buttonStyle(Home8ScalePressButtonStyle())
            .opacity(closeButtonOpacity(screenHeight: screenHeight))
            .offset(y: closeButtonOffsetY(screenHeight: screenHeight))
            .allowsHitTesting(ncViewModel.isExpanded)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    // MARK: - Home content view



    // MARK: - Opacity helpers

    private func closeButtonOpacity(screenHeight: CGFloat) -> CGFloat {
        if ncViewModel.isDragging { return ncViewModel.closeButtonOpacity(screenHeight: screenHeight) }
        if isTapClosing { return max(0, 1 - tapCloseProgress) }
        if ncViewModel.lastExpandTrigger == .tap { return ncViewModel.closeButtonRevealProgress(from: tapExpandProgress) }
        return staticCloseButtonOpacity
    }

    private func expandedContentOpacity(screenHeight: CGFloat) -> CGFloat {
        if ncViewModel.isDragging { return ncViewModel.expandedContentOpacity(screenHeight: screenHeight) }
        if ncViewModel.lastExpandTrigger == .tap { return ncViewModel.expandedContentOpacity(from: tapExpandProgress) }
        return ncViewModel.expandedContentOpacity(screenHeight: screenHeight)
    }

    private func collapsedTextOpacity(screenHeight: CGFloat) -> CGFloat {
        if ncViewModel.isDragging { return ncViewModel.collapsedTextOpacity(screenHeight: screenHeight) }
        if isTapClosing {
            let closeProgress = min(max(1 - tapExpandProgress, 0), 1)
            return min(max(
                (closeProgress - collapsedLabelTapCloseStart) /
                max(collapsedLabelTapCloseEnd - collapsedLabelTapCloseStart, 0.001),
                0), 1)
        }
        if ncViewModel.lastExpandTrigger == .tap { return ncViewModel.collapsedTextOpacity(from: tapExpandProgress) }
        return ncViewModel.collapsedTextOpacity(screenHeight: screenHeight)
    }

    private func closeButtonOffsetY(screenHeight: CGFloat) -> CGFloat {
        if isTapClosing { return 0 }
        if ncViewModel.isDragging { return ncViewModel.closeButtonOffsetY(screenHeight: screenHeight) }
        if ncViewModel.lastExpandTrigger == .tap {
            let reveal = ncViewModel.closeButtonRevealProgress(from: tapExpandProgress)
            guard ncViewModel.isExpanded else { return 0 }
            return (1 - reveal) * closeButtonOpenStartOffset
        }
        return staticCloseButtonOffsetY
    }

    private func syncCloseButtonOpacity(for isExpanded: Bool) {
        if isExpanded {
            isTapClosing = false
            tapCloseProgress = 0
            if ncViewModel.lastExpandTrigger == .drag && !isOpeningByIslandTap {
                staticCloseButtonOpacity = 1
                staticCloseButtonOffsetY = 0
            } else {
                staticCloseButtonOpacity = 0
                staticCloseButtonOffsetY = closeButtonOpenStartOffset
                tapExpandProgress = 0
                withAnimation(tapExpandAnimation) { tapExpandProgress = 1 }
            }
            isOpeningByIslandTap = false
            isClosingByCloseButtonTap = false
        } else {
            if isClosingByCloseButtonTap {
                isTapClosing = true
                tapCloseProgress = 0
                tapExpandProgress = 1
                withAnimation(tapCollapseAnimation) { tapExpandProgress = 0 }
                withAnimation(.easeOut(duration: closeButtonHideDuration)) { tapCloseProgress = 1 }
                isClosingByCloseButtonTap = false
                return
            }
            isTapClosing = false
            withAnimation(.easeOut(duration: 0.12)) {
                staticCloseButtonOpacity = 0
                staticCloseButtonOffsetY = 0
                tapExpandProgress = 0
            }
        }
    }

    // MARK: - Notification data

    private let importantNotifications: [Home8NotificationCard] = [
        .init(title: "Новый штраф 500 ₽", subtitle: "Geely Tugella", icon: "₽", iconSystemName: nil),
        .init(title: "Начислили кэшбек", subtitle: "+500 ₽ на Black", icon: "₽", iconSystemName: nil),
        .init(title: "Начислили кэшбек", subtitle: "+500 ₽ на Black", icon: "₽", iconSystemName: nil)
    ]

    private let interestingNotifications: [Home8NotificationCard] = [
        .init(title: "Возвращайтесь в 5 букв", subtitle: "И забирайте бонус", icon: nil, iconSystemName: "diamond.fill"),
        .init(title: "Возвращайтесь в 5 букв", subtitle: "И забирайте бонус", icon: nil, iconSystemName: "diamond.fill")
    ]

    private func notificationSection(title: String, cards: [Home8NotificationCard]) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.system(size: 30, weight: .bold))
                .kerning(0.36)
                .foregroundColor(primaryTextColor)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 16)
                .padding(.bottom, 8)
            VStack(spacing: 20) {
                ForEach(cards) { card in notificationCard(card) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 28)
    }

    private func notificationCard(_ model: Home8NotificationCard) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(model.title)
                    .font(.system(size: 17, weight: .semibold))
                    .kerning(-0.41)
                    .foregroundColor(primaryTextColor)
                    .lineLimit(1)
                Text(model.subtitle)
                    .font(.system(size: 15, weight: .regular))
                    .kerning(-0.24)
                    .foregroundColor(secondaryTextColor)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            ZStack {
                Circle().fill(iconBackgroundColor)
                if let icon = model.icon {
                    Text(icon).font(.system(size: 20, weight: .bold)).foregroundColor(primaryTextColor)
                } else if let name = model.iconSystemName {
                    Image(systemName: name).font(.system(size: 14, weight: .semibold)).foregroundColor(primaryTextColor)
                }
            }
            .frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
        .frame(height: 80)
        .background(cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(
            color: colorScheme == .dark ? Color.clear : Color.black.opacity(0.10),
            radius: 20, x: 0, y: 5
        )
    }

    // MARK: - Stub tab

    private func home8StubTab(_ tab: Home8Tab) -> some View {
        ZStack {
            Rectangle()
                .fill(contentBackgroundStyle)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: tab.symbolName)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(primaryTextColor.opacity(0.72))

                Text(tab.title)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(primaryTextColor)

                Text("Вкладка пока в работе")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(secondaryTextColor)
            }
            .padding(.bottom, 80)
        }
    }
}

// MARK: - Content views

private extension TestInAppView {

    var homeHeaderBar: some View {
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 12) {
                    homeHeaderBarContent
                }
            } else {
                homeHeaderBarContent
            }
        }
        .frame(height: 44)
    }

    var homeHeaderBarContent: some View {
        ZStack {
            HStack(spacing: 0) {
                homeAvatarButton
                Spacer()
                homeSearchButton
            }

            homeAccountsButton
        }
    }

    @ViewBuilder
    var homeAccountsDisplaySection: some View {
        switch homeMainDisplayMode {
        case .focus:
            homeFocusAccountSection
        case .compact:
            homeCompactAccountsSection
        }
    }

    var compactAppearanceEditorPresented: Binding<Bool> {
        Binding {
            editingCompactAppearanceAccountID != nil
        } set: { isPresented in
            if !isPresented {
                editingCompactAppearanceAccountID = nil
            }
        }
    }

    var editingCompactAppearanceAccount: Home8FocusAccount? {
        guard let accountID = editingCompactAppearanceAccountID else { return nil }
        return homeAccount(for: accountID)
    }

    func compactAppearance(for account: Home8FocusAccount) -> HomeAccountCompactAppearance {
        homeAccountAppearances[account.id] ?? .default(for: account)
    }

    func compactAppearanceBinding(for account: Home8FocusAccount) -> Binding<HomeAccountCompactAppearance> {
        Binding {
            compactAppearance(for: account)
        } set: { newValue in
            if newValue == HomeAccountCompactAppearance.default(for: account) {
                homeAccountAppearances.removeValue(forKey: account.id)
            } else {
                homeAccountAppearances[account.id] = newValue
            }
        }
    }

    func accountNameBinding(for account: Home8FocusAccount) -> Binding<String> {
        Binding {
            homeAccount(for: account.id)?.title ?? account.title
        } set: { newValue in
            let fallbackTitle = defaultHomeAccountTitle(for: account.id) ?? account.title
            let trimmedTitle = String(newValue.prefix(30)).trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedTitle.isEmpty || trimmedTitle == fallbackTitle {
                homeAccountTitleOverrides.removeValue(forKey: account.id)
            } else {
                homeAccountTitleOverrides[account.id] = trimmedTitle
            }
        }
    }

    func editCompactAppearance(for account: Home8FocusAccount) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        editingCompactAppearanceAccountID = account.id
    }

    func hideCompactAccountFromHome(_ account: Home8FocusAccount) {
        guard homeVisibleAccountIDs.count > 1 else { return }

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred(intensity: 0.72)

        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
            homeVisibleAccountIDs.removeAll { $0 == account.id }
        }
    }

    var homeFocusAccountSection: some View {
        GeometryReader { proxy in
            let pageWidth = proxy.size.width

            ZStack(alignment: .top) {
                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        ForEach(homeMainAccounts) { account in
                            homeFocusAccountPage(account)
                                .frame(width: pageWidth, height: homeFocusAccountSectionHeight, alignment: .top)
                        }
                    }
                    .offset(x: -CGFloat(focusedAccountIndex) * pageWidth + focusAccountDragOffset)
                    .animation(
                        .interactiveSpring(response: 0.34, dampingFraction: 0.86),
                        value: focusedAccountIndex
                    )
                }
                .frame(width: pageWidth, height: homeFocusAccountSectionHeight, alignment: .leading)
                .clipped()
                .overlay(alignment: .top) {
                    Color.clear
                        .frame(height: homeFocusAccountPocketOffsetY)
                        .contentShape(Rectangle())
                        .simultaneousGesture(homeFocusAccountDragGesture(pageWidth: pageWidth))
                }

                homeCardPocket
                    .frame(height: 108)
                    .padding(.horizontal, -14)
                    .offset(y: homeFocusAccountPocketOffsetY)
                    .zIndex(1)
            }
            .frame(width: pageWidth, height: homeFocusAccountSectionHeight, alignment: .top)
        }
        .frame(height: homeFocusAccountSectionHeight)
    }

    private var homeFocusAccountSectionHeight: CGFloat {
        382
    }

    private var homeFocusAccountPocketOffsetY: CGFloat {
        274
    }

    private var homeFocusAccountCardTopPadding: CGFloat {
        40
    }

    private var homeFocusAccountSummaryHeight: CGFloat {
        152
    }

    private var homeFocusAccountCardHeight: CGFloat {
        140
    }

    var homeCompactAccountsSection: some View {
        VStack(spacing: 0) {
            Group {
                if homeCompactPageCount > 1 {
                    homeCompactAccountsPager
                } else {
                    homeCompactAccountsGrid(accounts: homeMainAccounts)
                }
            }
            .frame(height: homeCompactGridHeight + homeCompactGridShadowBleed, alignment: .top)
            .padding(.top, 32)

            homeStandaloneQuickActionsPanel
                .padding(.top, 6 - homeCompactGridShadowBleed)
        }
        .frame(maxWidth: .infinity)
        .frame(height: homeCompactAccountsSectionHeight, alignment: .top)
    }

    private var homeCompactAccountsPager: some View {
        GeometryReader { proxy in
            let pageWidth = proxy.size.width
            let pageStep = pageWidth + homeCompactPageSpacing

            HStack(alignment: .top, spacing: homeCompactPageSpacing) {
                ForEach(homeCompactAccountPages.indices, id: \.self) { pageIndex in
                    homeCompactAccountsGrid(accounts: homeCompactAccountPages[pageIndex])
                        .frame(width: pageWidth, height: homeCompactGridHeight, alignment: .top)
                }
            }
            .offset(x: -CGFloat(compactAccountsPageIndex) * pageStep + compactAccountsDragOffset)
            .animation(
                .interactiveSpring(response: 0.34, dampingFraction: 0.86),
                value: compactAccountsPageIndex
            )
            .frame(width: pageWidth, height: homeCompactGridHeight + homeCompactGridShadowBleed, alignment: .topLeading)
            .contentShape(Rectangle())
            .simultaneousGesture(homeCompactAccountsDragGesture(pageWidth: pageWidth))
        }
    }

    private func homeCompactAccountsGrid(accounts: [Home8FocusAccount]) -> some View {
        VStack(spacing: 16) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 16) {
                    ForEach(0..<2, id: \.self) { column in
                        homeCompactAccountSlot(accounts: accounts, index: row * 2 + column)
                    }
                }
            }
        }
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, minHeight: homeCompactGridHeight, maxHeight: homeCompactGridHeight, alignment: .top)
    }

    @ViewBuilder
    private func homeCompactAccountSlot(accounts: [Home8FocusAccount], index: Int) -> some View {
        if accounts.indices.contains(index) {
            homeCompactAccountCard(accounts[index])
        } else {
            Color.clear
                .frame(height: 132)
                .frame(maxWidth: .infinity)
        }
    }

    private var homeCompactGridHeight: CGFloat {
        280
    }

    private var homeCompactGridShadowBleed: CGFloat {
        20
    }

    private var homeCompactPageSpacing: CGFloat {
        20
    }

    private var homeCompactAccountsSectionHeight: CGFloat {
        32 + homeCompactGridHeight + 6 + 108
    }

    private var homeCompactAccountPages: [[Home8FocusAccount]] {
        let accounts = homeMainAccounts
        return stride(from: 0, to: accounts.count, by: 4).map { startIndex in
            let endIndex = min(startIndex + 4, accounts.count)
            return Array(accounts[startIndex..<endIndex])
        }
    }

    private var homeCompactPageCount: Int {
        max(1, homeCompactAccountPages.count)
    }

    private func homeCompactAccountsDragGesture(pageWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard homeCompactPageCount > 1, abs(value.translation.width) > abs(value.translation.height) else { return }
                isHomeAccountsHorizontalSwipeActive = true
                showFocusAccountDots()

                let isAtFirstPage = compactAccountsPageIndex == 0 && value.translation.width > 0
                let isAtLastPage = compactAccountsPageIndex == homeCompactPageCount - 1 && value.translation.width < 0
                let resistance: CGFloat = (isAtFirstPage || isAtLastPage) ? 0.28 : 1

                compactAccountsDragOffset = value.translation.width * resistance
            }
            .onEnded { value in
                defer { isHomeAccountsHorizontalSwipeActive = false }
                guard homeCompactPageCount > 1, abs(value.translation.width) > abs(value.translation.height) else {
                    settleCompactAccountsDrag()
                    return
                }

                let threshold = pageWidth * 0.18
                var nextIndex = compactAccountsPageIndex

                if value.predictedEndTranslation.width < -threshold || value.translation.width < -threshold {
                    nextIndex = min(homeCompactPageCount - 1, compactAccountsPageIndex + 1)
                } else if value.predictedEndTranslation.width > threshold || value.translation.width > threshold {
                    nextIndex = max(0, compactAccountsPageIndex - 1)
                }

                if nextIndex != compactAccountsPageIndex {
                    playHomeAccountSwipeHaptic()
                }

                withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.86)) {
                    compactAccountsPageIndex = nextIndex
                    compactAccountsDragOffset = 0
                }

                scheduleFocusAccountDotsHide()
            }
    }

    func homeCompactAccountCard(_ account: Home8FocusAccount) -> some View {
        let appearance = homeAccountAppearances[account.id]
        let isTinted = appearance?.backgroundHex != nil
        let titleColor = isTinted ? Color.white : primaryTextColor
        let subtitleColor = isTinted ? Color.white.opacity(0.86) : secondaryTextColor
        let cardShape = RoundedRectangle(cornerRadius: 32, style: .continuous)
        let compactCardBackground = appearance?.compactCardBackground(defaultColor: cardBackgroundColor) ?? cardBackgroundColor

        return VStack(alignment: .leading, spacing: 0) {
            Group {
                if let appearance {
                    homeCompactAccountVisual(account, appearance: appearance, isTinted: isTinted)
                } else {
                    homeDefaultCompactAccountVisual(account)
                }
            }
                .frame(height: 34, alignment: .topLeading)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text(account.balance(kopecksHidden: areHomeKopecksHidden))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .kerning(-0.41)
                    .foregroundColor(titleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(account.title)
                    .font(.system(size: 15, weight: .regular))
                    .kerning(-0.24)
                    .foregroundColor(subtitleColor)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .frame(height: 132)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            cardShape.fill(compactCardBackground)
        }
        .clipShape(cardShape)
        .contentShape(cardShape)
        .contentShape(.contextMenuPreview, cardShape)
        .shadow(
            color: Color.black.opacity(isTinted || colorScheme == .dark ? 0 : 0.05),
            radius: 20,
            x: 0,
            y: 5
        )
        .contextMenu {
            Button {
                resetHomeAccountsDragState()
                editCompactAppearance(for: account)
            } label: {
                Label("Настроить", systemImage: "paintpalette")
            }

            Button {
                resetHomeAccountsDragState()
                hideCompactAccountFromHome(account)
            } label: {
                Label("Скрыть", systemImage: "eye.slash")
            }
            .disabled(homeVisibleAccountIDs.count <= 1)
        }
    }

    @ViewBuilder
    func homeDefaultCompactAccountVisual(_ account: Home8FocusAccount) -> some View {
        Image(systemName: account.defaultCompactSystemIconName)
            .font(.system(size: 32, weight: .semibold))
            .foregroundColor(Color(hex: "428BF9"))
            .frame(width: 34, height: 34, alignment: .topLeading)
    }

    @ViewBuilder
    func homeCompactAccountVisual(
        _ account: Home8FocusAccount,
        appearance: HomeAccountCompactAppearance,
        isTinted: Bool
    ) -> some View {
        Group {
            if let systemIconName = appearance.systemIconName {
                Image(systemName: systemIconName)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(appearance.avatarForegroundColor)
            } else {
                Text(appearance.emoji)
                    .font(.system(size: 32))
                    .foregroundColor(isTinted ? .white : appearance.avatarForegroundColor)
                    .lineLimit(1)
            }
        }
        .frame(width: 34, height: 34, alignment: .topLeading)
    }

    private func homeAccountCardThumbnail(_ account: Home8FocusAccount, number: String, index: Int) -> some View {
        ZStack(alignment: .bottomLeading) {
            switch account.cardStyle {
            case .black:
                Image("card")
                    .resizable()
                    .scaledToFill()
                    .saturation(index == 0 ? 1 : 0)
                    .brightness(index == 0 ? 0 : 0.08)
            case .platinum:
                Image("card")
                    .resizable()
                    .scaledToFill()
                    .saturation(0)
                    .brightness(0.18)
            case .savings, .joint, .wallet:
                LinearGradient(
                    colors: [Color(hex: "7CAEFF"), Color(hex: "4972CF")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            if !number.isEmpty {
                Text(number)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.leading, 4)
                    .padding(.bottom, 3)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    var homeStandaloneQuickActionsPanel: some View {
        HStack(spacing: 0) {
            ForEach(homeQuickActions) { action in
                homeQuickActionItem(action)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .frame(height: 108, alignment: .top)
    }

    func homeFocusAccountPage(_ account: Home8FocusAccount) -> some View {
        VStack(spacing: 0) {
            homeAccountSummary(account)
            homeCardSection(account)
        }
    }

    func homeAccountSummary(_ account: Home8FocusAccount) -> some View {
        VStack(spacing: 5) {
            Text(account.title)
                .font(.system(size: 15, weight: .semibold))
                .kerning(-0.24)
                .foregroundColor(primaryTextColor)

            Text(account.balance(kopecksHidden: areHomeKopecksHidden))
                .foregroundColor(primaryTextColor)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .kerning(0.36)
                .minimumScaleFactor(0.72)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 68)
        .frame(height: homeFocusAccountSummaryHeight, alignment: .top)
    }

    func homeCardSection(_ account: Home8FocusAccount) -> some View {
        ZStack(alignment: .top) {
            homeFocusCard(account)
                .frame(width: 210, height: homeFocusAccountCardHeight)
                .offset(y: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 179)
        .padding(.top, homeFocusAccountCardTopPadding)
    }

    @ViewBuilder
    func homeFocusCard(_ account: Home8FocusAccount) -> some View {
        switch account.cardStyle {
        case .black:
            Image("card")
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        case .platinum:
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(hex: "D8D8D8"))
                .overlay(alignment: .leading) {
                    Circle()
                        .fill(Color(hex: "B8B8B8").opacity(0.82))
                        .frame(width: 162, height: 162)
                        .offset(x: -42, y: -4)
                }
                .overlay(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(hex: "757575"))
                        .frame(width: 24, height: 24)
                        .overlay {
                            Text("T")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.78))
                        }
                        .padding(.top, 16)
                        .padding(.trailing, 16)
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        case .savings:
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.clear)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            colorScheme == .dark ? Color.white.opacity(0.22) : Color(hex: "CDD2DA"),
                            style: StrokeStyle(lineWidth: 1.6, dash: [8, 8])
                        )
                }
        case .joint:
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "7CAEFF"), Color(hex: "4972CF")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 72, height: 72)
                        .offset(x: -18, y: -18)
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        case .wallet:
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(hex: "DCE8FF"))
                .overlay {
                    Image(systemName: "wallet.pass.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(Color(hex: "428BF9"))
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    func homeFocusAccountDragGesture(pageWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard isHomeAccountsHorizontalSwipeActive || isHorizontalHomeAccountSwipe(value) else { return }

                isHomeAccountsHorizontalSwipeActive = true
                showFocusAccountDots()
                let isAtFirstAccount = focusedAccountIndex == 0 && value.translation.width > 0
                let isAtLastAccount = focusedAccountIndex == homeMainAccounts.count - 1 && value.translation.width < 0
                let resistance: CGFloat = (isAtFirstAccount || isAtLastAccount) ? 0.28 : 1

                focusAccountDragOffset = value.translation.width * resistance
            }
            .onEnded { value in
                defer { isHomeAccountsHorizontalSwipeActive = false }
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    settleFocusAccountDrag()
                    return
                }

                let threshold = pageWidth * 0.18
                var nextIndex = focusedAccountIndex

                if value.predictedEndTranslation.width < -threshold || value.translation.width < -threshold {
                    nextIndex = min(homeMainAccounts.count - 1, focusedAccountIndex + 1)
                } else if value.predictedEndTranslation.width > threshold || value.translation.width > threshold {
                    nextIndex = max(0, focusedAccountIndex - 1)
                }

                if nextIndex != focusedAccountIndex {
                    playHomeAccountSwipeHaptic()
                }

                withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.86)) {
                    focusedAccountIndex = nextIndex
                    focusAccountDragOffset = 0
                }

                scheduleFocusAccountDotsHide()
            }
    }

    var homeQuickActionsSection: some View {
        Color.clear
            .frame(height: 5)
    }

    var homeInsightsCardsSection: some View {
        VStack(spacing: 20) {
            homeOperationsCard
            homeCashbackCard
            homeSavingsCard
            homeCreditsCard
            homeFamilyCard
            homeMobileCard
        }
        .padding(.top, 12)
    }

    var homeOperationsCard: some View {
        homeInsightCard(title: "Все операции") {
            homeInsightAmount("3 025 ₽")
        } subtitle: {
            homeInsightSubtitle("Трат сегодня")
        } accessory: {
            homeOperationsBars
        }
    }

    var homeCashbackCard: some View {
        homeInsightCard(title: "Кэшбэк и бонусы") {
            homeInsightAmount("25%")
        } subtitle: {
            homeInsightSubtitle("Кэшбэк на пиццу")
        } accessory: {
            homeCashbackBadges
        }
    }

    var homeSavingsCard: some View {
        homeInsightCard(title: "Накопления") {
            homeInsightAmount("1 378 000 ₽")
        } subtitle: {
            Text("Проценты \(Text("+10 230 ₽").foregroundStyle(homePositiveAmountStyle).fontWeight(.semibold))")
            .foregroundColor(secondaryTextColor)
            .font(.system(size: 15, weight: .regular))
            .kerning(-0.24)
        } accessory: {
            homeSavingsGraph
        }
    }

    var homeCreditsCard: some View {
        homeInsightCard(title: "Кредиты") {
            homeInsightAmount("1 000 ₽")
        } subtitle: {
            homeInsightSubtitle("Завтра платеж по кредиту")
        } accessory: {
            homeCreditsGrid
        }
    }

    var homeFamilyCard: some View {
        homeInsightCard(title: "Семья") {
            homeInsightAmount("Шиловичи")
                .kerning(-0.41)
        } subtitle: {
            homeInsightSubtitle("Скоро день рождение кота")
        } accessory: {
            homeFamilyPhotos
        }
    }

    var homeMobileCard: some View {
        homeInsightCard(title: "Мобайл", cornerRadius: 24) {
            homeInsightAmount("+7 933 222 21-21")
        } subtitle: {
            homeInsightSubtitle("Спишем 219 ₽ через 3 дня")
        } accessory: {
            homeMobileMeters
        }
    }

    func homeInsightCard<Amount: View, Subtitle: View, Accessory: View>(
        title: String,
        cornerRadius: CGFloat = 28,
        @ViewBuilder amount: () -> Amount,
        @ViewBuilder subtitle: () -> Subtitle,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .kerning(-0.24)
                    .foregroundColor(primaryTextColor)

                Spacer(minLength: 0)

                amount()
                    .frame(maxWidth: .infinity, alignment: .leading)

                subtitle()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            accessory()
                .frame(height: 78)
                .frame(minWidth: 60, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 112)
        .background(homeInsightCardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(
            color: colorScheme == .dark ? Color.clear : Color.black.opacity(0.05),
            radius: 20,
            x: 0,
            y: 5
        )
    }

    func homeInsightAmount(_ value: String) -> Text {
        Text(value)
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundColor(primaryTextColor)
    }

    func homeInsightSubtitle(_ value: String) -> Text {
        Text(value)
            .font(.system(size: 15, weight: .regular))
            .kerning(-0.24)
            .foregroundColor(secondaryTextColor)
    }

    var homeOperationsBars: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array([12, 18, 26, 32, 40].enumerated()), id: \.offset) { index, height in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(index == 4 ? homePositiveAmountStyle : AnyShapeStyle(homeOperationsCardBadgeBackground))
                    .frame(width: 13, height: CGFloat(height))
            }
        }
        .frame(width: 80, height: 72, alignment: .bottomTrailing)
    }

    var homeCashbackBadges: some View {
        HStack(spacing: 6) {
            homePartnerBadge(
                title: "D",
                background: Color(hex: "FF6B00"),
                foreground: .white
            )
            homePartnerBadge(
                title: "M",
                background: Color(hex: "FFE45C"),
                foreground: .black
            )
            homePartnerBadge(
                title: "C",
                background: Color(hex: "5B31A7"),
                foreground: .white
            )
        }
        .frame(height: 72, alignment: .bottom)
    }

    var homeSavingsGraph: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(homeOperationsCardBadgeBackground)
            .frame(width: 60, height: 72)
            .overlay(alignment: .bottom) {
                Home8SavingsGraphLine()
                    .stroke(homePositiveAmountStyle, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    .frame(width: 52, height: 36)
                    .padding(.bottom, 9)
            }
            .overlay(alignment: .topTrailing) {
                Text("+7%")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(homePositiveAmountStyle)
                    )
                    .padding(.top, 7)
                    .padding(.trailing, 5)
            }
    }

    var homeCreditsGrid: some View {
        RoundedRectangle(cornerRadius: 11.2, style: .continuous)
            .fill(homeOperationsCardBadgeBackground)
            .frame(width: 60, height: 72)
            .overlay {
                VStack(spacing: 1.6) {
                    ForEach(0..<5, id: \.self) { row in
                        HStack(spacing: 1.6) {
                            ForEach(0..<5, id: \.self) { column in
                                RoundedRectangle(cornerRadius: 2.4, style: .continuous)
                                    .fill(homeCreditCellStyle(row: row, column: column))
                                    .frame(width: 10.2, height: 10.2)
                            }
                        }
                    }
                }
            }
    }

    var homeFamilyPhotos: some View {
        ZStack {
            homeFamilyPhoto(imageName: "sample")
                .rotationEffect(.degrees(-10))
                .offset(x: -21, y: 1)
            homeFamilyPhoto(imageName: "card")
                .offset(x: 0, y: 0)
            homeFamilyPhoto(imageName: "sample")
                .rotationEffect(.degrees(10))
                .offset(x: 21, y: 0)
        }
        .frame(width: 92, height: 78)
    }

    var homeMobileMeters: some View {
        HStack(spacing: 4) {
            homeMobileMeter(
                fill: LinearGradient(
                    colors: [Color(hex: "3A8AF7"), Color(hex: "4054C8")],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                fillHeight: 38,
                symbolName: "globe"
            )
            homeMobileMeter(
                fill: LinearGradient(
                    colors: [Color(hex: "1EEC8F"), Color(hex: "11C452")],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                fillHeight: 63,
                symbolName: "phone.fill"
            )
        }
        .frame(width: 56, height: 72, alignment: .trailing)
    }

    func homeCreditCellStyle(row: Int, column: Int) -> AnyShapeStyle {
        let activeCountByRow = [5, 3, 2, 1, 0]
        let isActive = column < activeCountByRow[row]
        let inactiveFill = colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.08)
        return isActive ? homePositiveAmountStyle : AnyShapeStyle(inactiveFill)
    }

    func homeFamilyPhoto(imageName: String) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(hex: "9F9F9F"))
            .frame(width: 56, height: 69)
            .overlay {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 69)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .opacity(imageName == "card" ? 0.85 : 1)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.9), lineWidth: 0.5)
            )
    }

    func homeMobileMeter(fill: LinearGradient, fillHeight: CGFloat, symbolName: String) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(homeOperationsCardBadgeBackground)
            .frame(width: 26, height: 72)
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(fill)
                    .frame(height: fillHeight)
                    .opacity(0.9)
            }
            .overlay(alignment: .bottom) {
                Image(systemName: symbolName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 16, height: 16)
                    .padding(.bottom, 5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    func homePartnerBadge(title: String, background: Color, foreground: Color) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(background)
            .frame(width: 36, height: 36)
            .overlay {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(foreground)
            }
    }

    func homeQuickActionItem(_ action: Home8QuickAction) -> some View {
        VStack(spacing: 8) {
            Button {
                handleHomeQuickActionTap(action)
            } label: {
                homeQuickActionIcon(action)
                    .frame(width: 56, height: 56)
            }
            .buttonStyle(.plain)
            .modifier(Home8ActionGlassButtonModifier(shape: action.glassShape))
            .frame(width: 56, height: 56)

            Text(action.title)
                .font(.system(size: 13, weight: .regular))
                .kerning(-0.08)
                .foregroundColor(primaryTextColor)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 80, alignment: .top)
    }

    private func handleHomeQuickActionTap(_ action: Home8QuickAction) {
        guard action.title == "Недавнее" else { return }
        playHomeAccountSwipeHaptic()
        recentFolderAnimationProgress = 0
        isRecentFolderPresented = true

        DispatchQueue.main.async {
            guard isRecentFolderPresented else { return }
            withAnimation(homeRecentFolderAnimation) {
                recentFolderAnimationProgress = 1
            }
        }

    }

    @ViewBuilder
    func homeQuickActionIcon(_ action: Home8QuickAction) -> some View {
        switch action.title {
        case "Сканировать":
            Image(systemName: "viewfinder")
                .font(.system(size: 24, weight: .regular))
                .foregroundColor(primaryTextColor)
        case "Перевести":
            Image(systemName: "arrow.right")
                .font(.system(size: 24, weight: .regular))
                .foregroundColor(primaryTextColor)
        case "Недавнее":
            homeRecentActionIcon
        default:
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .regular))
                .foregroundColor(primaryTextColor)
        }
    }

    var homeRecentActionIcon: some View {
        ZStack {
            ForEach(Array(homeRecentFolderItems.prefix(4).enumerated()), id: \.element.id) { index, item in
                homeRecentFolderAvatar(item, size: 18)
                    .position(homeRecentPreviewPosition(for: index))
            }
        }
        .frame(width: 40, height: 40)
    }

    private var homeRecentFolderAnimation: Animation {
        .timingCurve(0.4, 0.1, 0.2, 1.0, duration: 0.50)
    }

    private var homeRecentFolderItems: [HomeRecentFolderItem] {
        [
            .init(id: "mobile", title: "Мобильная\nсвязь", assetName: "HomeRecentAvatar0"),
            .init(id: "fuel", title: "Топливо", assetName: "HomeRecentAvatar1"),
            .init(id: "evgeny", title: "Евгений К.", assetName: "HomeRecentAvatar2"),
            .init(id: "daniil", title: "Даниил", assetName: "HomeRecentAvatar3"),
            .init(id: "mom", title: "Мама", assetName: "HomeRecentAvatar4"),
            .init(id: "self", title: "Себе", assetName: "HomeRecentAvatar5"),
            .init(id: "internet", title: "Интернет", assetName: "HomeRecentAvatar6"),
            .init(id: "letters", title: "5 букв", assetName: "HomeRecentAvatar7")
        ]
    }

    private func homeRecentPreviewPosition(for index: Int) -> CGPoint {
        switch index {
        case 0:
            return CGPoint(x: 9, y: 9)
        case 1:
            return CGPoint(x: 31, y: 9)
        case 2:
            return CGPoint(x: 9, y: 31)
        default:
            return CGPoint(x: 31, y: 31)
        }
    }

    @ViewBuilder
    private func homeRecentFolderOverlay(screenSize: CGSize) -> some View {
        let progress = recentFolderAnimationProgress
        let backgroundProgress = homeRecentEaseOut(progress)
        let titleProgress = homeRecentDelayedProgress(progress, delay: 0.08, duration: 0.28)
        let closeProgress = homeRecentDelayedProgress(progress, delay: 0.58, duration: 0.24)

        ZStack {
            Home8VisualEffectBlur(style: colorScheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight)
                .opacity(backgroundProgress)
                .overlay(Color.white.opacity((colorScheme == .dark ? 0.02 : 0.54) * backgroundProgress))
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .ignoresSafeArea()
                .onTapGesture {
                    closeHomeRecentFolder()
                }

            Text("Недавнее")
                .font(.system(size: 20, weight: .bold, design: .default))
                .kerning(0.38)
                .foregroundColor(primaryTextColor)
                .scaleEffect(0.96 + 0.04 * titleProgress)
                .opacity(titleProgress)
                .position(x: screenSize.width / 2, y: screenSize.height * 0.355)

            ForEach(Array(homeRecentFolderItems.enumerated()), id: \.element.id) { index, item in
                homeRecentFolderItem(item, progress: homeRecentFolderItemProgress(index: index))
                    .position(homeRecentFolderCurrentPosition(index: index, screenSize: screenSize))
            }

            homeRecentFolderCloseButton
                .opacity(closeProgress)
                .scaleEffect(0.96 + 0.04 * closeProgress)
                .offset(y: 10 * (1 - closeProgress))
                .position(x: screenSize.width / 2, y: screenSize.height * 0.908)
        }
    }

    private func homeRecentFolderItemProgress(index: Int) -> CGFloat {
        homeRecentEaseOut(recentFolderAnimationProgress)
    }

    private func homeRecentFolderCurrentPosition(index: Int, screenSize: CGSize) -> CGPoint {
        let progress = homeRecentFolderItemProgress(index: index)
        let start = homeRecentFolderSourcePosition(screenSize: screenSize)
        let end = homeRecentFolderFinalPosition(index: index, screenSize: screenSize)

        return CGPoint(
            x: start.x + (end.x - start.x) * progress,
            y: start.y + (end.y - start.y) * progress
        )
    }

    private func homeRecentFolderSourcePosition(screenSize: CGSize) -> CGPoint {
        CGPoint(
            x: screenSize.width - 51,
            y: screenSize.height * 0.635
        )
    }

    private func homeRecentFolderFinalPosition(index: Int, screenSize: CGSize) -> CGPoint {
        let columns = 4
        let column = index % columns
        let row = index / columns
        let horizontalInset: CGFloat = 20
        let columnWidth = max((screenSize.width - horizontalInset * 2) / CGFloat(columns), 1)
        let x = horizontalInset + columnWidth * (CGFloat(column) + 0.5)
        let row1Y = screenSize.height * 0.468
        let rowGap = screenSize.height * 0.130

        return CGPoint(
            x: x,
            y: row1Y + CGFloat(row) * rowGap
        )
    }

    private func homeRecentDelayedProgress(
        _ progress: CGFloat,
        delay: CGFloat,
        duration: CGFloat
    ) -> CGFloat {
        guard duration > 0 else { return progress >= delay ? 1 : 0 }
        let normalized = min(max((progress - delay) / duration, 0), 1)
        return homeRecentEaseOut(normalized)
    }

    private func homeRecentEaseOut(_ value: CGFloat) -> CGFloat {
        let clamped = min(max(value, 0), 1)
        return 1 - pow(1 - clamped, 3)
    }

    private func homeRecentFolderItem(_ item: HomeRecentFolderItem, progress: CGFloat) -> some View {
        let labelProgress = homeRecentDelayedProgress(progress, delay: 0.54, duration: 0.24)

        return VStack(spacing: 6) {
            homeRecentFolderAvatar(item, size: 56)
                .scaleEffect(0.32 + 0.68 * progress)

            Text(item.title)
                .font(.system(size: 12, weight: .regular))
                .kerning(0)
                .foregroundColor(primaryTextColor)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 30, alignment: .top)
                .opacity(labelProgress)
                .offset(y: 8 * (1 - labelProgress))
        }
        .frame(width: 84)
        .opacity(0.65 + 0.35 * progress)
    }

    private func homeRecentFolderAvatar(_ item: HomeRecentFolderItem, size: CGFloat) -> some View {
        Image(item.assetName)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
    }

    private var homeRecentFolderCloseButton: some View {
        Button {
            closeHomeRecentFolder()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))

                Text("Закрыть")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(primaryTextColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(closeButtonBackgroundColor)
            .clipShape(Capsule())
        }
        .buttonStyle(Home8ScalePressButtonStyle())
        .accessibilityLabel("Закрыть папку Недавнее")
    }

    private func closeHomeRecentFolder() {
        playHomeAccountSwipeHaptic()
        withAnimation(.easeInOut(duration: 0.24)) {
            recentFolderAnimationProgress = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            isRecentFolderPresented = false
        }
    }

    @ViewBuilder
    var homeCardPocket: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Group {
                    if colorScheme == .dark {
                        Home8CardPocketShadowShape()
                            .fill(Color(hex: "2F2F2F").opacity(0.10))
                            .frame(
                                width: proxy.size.width * 325.126 / 375,
                                height: proxy.size.height * 83.1372 / 108
                            )
                            .blur(radius: 8.9)
                            .position(
                                x: proxy.size.width / 2,
                                y: proxy.size.height * 2 / 108 + proxy.size.height * 83.1372 / 216
                            )

                        Home8VisualEffectBlur(style: .systemUltraThinMaterialDark)
                            .clipShape(Home8CardPocketShape())

                        Home8CardPocketShape()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.black.opacity(0.60),
                                        Color.black.opacity(0.75)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        Home8CardPocketShape()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.black,
                                        Color.black.opacity(0)
                                    ],
                                    startPoint: .trailing,
                                    endPoint: UnitPoint(x: 0.7543, y: 0.255)
                                )
                            )

                        Home8CardPocketShape()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.black,
                                        Color.black.opacity(0.20)
                                    ],
                                    startPoint: .leading,
                                    endPoint: UnitPoint(x: 0.2437, y: 0.255)
                                )
                            )

                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            LinearGradient(
                                colors: [Color.black.opacity(0), Color.black],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 27)
                        }
                        .clipShape(Home8CardPocketShape())

                        Home8CardPocketTopStrokeShape()
                            .stroke(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.white.opacity(0), location: 0.1),
                                        .init(color: Color.white.opacity(0.15), location: 0.350789),
                                        .init(color: Color.white.opacity(0.15), location: 0.603578),
                                        .init(color: Color.white.opacity(0), location: 0.9)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
                            )
                    } else {
                        Home8CardPocketShadowShape()
                            .fill(Color.black.opacity(0.06))
                            .frame(
                                width: proxy.size.width * 325.126 / 375,
                                height: proxy.size.height * 83.1372 / 108
                            )
                            .blur(radius: 10)
                            .position(
                                x: proxy.size.width / 2,
                                y: proxy.size.height * 2 / 108 + proxy.size.height * 83.1372 / 216
                            )

                        Home8VisualEffectBlur(style: .systemUltraThinMaterialLight)
                            .clipShape(Home8CardPocketShape())

                        Home8CardPocketShape()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.62),
                                        Color.white.opacity(0.42)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        Home8CardPocketShape()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "F8F8F8").opacity(0.9),
                                        Color(hex: "F8F8F8").opacity(0)
                                    ],
                                    startPoint: .trailing,
                                    endPoint: UnitPoint(x: 0.7543, y: 0.255)
                                )
                            )

                        Home8CardPocketShape()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "F8F8F8").opacity(0.9),
                                        Color(hex: "F8F8F8").opacity(0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: UnitPoint(x: 0.2437, y: 0.255)
                                )
                            )

                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            LinearGradient(
                                colors: [Color(hex: "F8F8F8").opacity(0), Color(hex: "F8F8F8")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 26)
                        }
                        .clipShape(Home8CardPocketShape())

                        Home8CardPocketTopStrokeShape()
                            .stroke(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.black.opacity(0), location: 0.1),
                                        .init(color: Color.black.opacity(0.08), location: 0.350789),
                                        .init(color: Color.black.opacity(0.08), location: 0.603578),
                                        .init(color: Color.black.opacity(0), location: 0.9)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
                            )
                    }
                }
                .allowsHitTesting(false)

                HStack(spacing: 0) {
                    ForEach(homeQuickActions) { action in
                        homeQuickActionItem(action)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 8)
            }
        }
    }

    var homeAvatarButton: some View {
        Button(action: {}) {
            ZStack(alignment: .center) {
                Image("sample")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            }
            .frame(width: 44, height: 44)
        }
        .modifier(Home8GlassButtonModifier(shape: .circle))
        .frame(width: 44, height: 44)
    }

    var homeAccountsButton: some View {
        NavigationLink {
            HomeAccountsOverviewView(
                allAccounts: homeAllAccounts,
                accountAppearances: homeAccountAppearances,
                selectedIndex: $focusedAccountIndex,
                displayMode: $homeMainDisplayMode,
                areKopecksHidden: $areHomeKopecksHidden,
                visibleAccountIDs: $homeVisibleAccountIDs
            )
        } label: {
            ZStack {
                Text("Счета и карты")
                    .font(.system(size: 15, weight: .medium))
                    .kerning(-0.23)
                    .foregroundColor(homeControlTextColor)
                    .opacity(isFocusAccountPagerVisible ? 0 : 1)
                    .animation(homeAccountsCrossfadeAnimation, value: isFocusAccountPagerVisible)

                homeFocusAccountDots
                    .opacity(isFocusAccountPagerVisible ? 1 : 0)
                    .animation(homeAccountsCrossfadeAnimation, value: isFocusAccountPagerVisible)
            }
            .frame(width: 137, height: 44)
        }
        .modifier(Home8GlassButtonModifier(shape: .capsule))
        .frame(width: 137, height: 44)
        .simultaneousGesture(
            TapGesture().onEnded {
                beginHomeNavigationTransition(reason: "accounts")
            }
        )
    }

    var homeSearchButton: some View {
        Button(action: {
            dismiss()
        }) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 21, weight: .medium))
                .foregroundColor(homeControlTextColor)
                .frame(width: 44, height: 44)
        }
        .modifier(Home8GlassButtonModifier(shape: .circle))
        .frame(width: 44, height: 44)
    }

    var homeFocusAccountDots: some View {
        HStack(spacing: 9) {
            ForEach(homeAccountsPagerDots) { dot in
                Circle()
                    .fill(dot.index == homeAccountsPagerSelectedIndex ? homeFocusDotActiveColor : homeFocusDotInactiveColor)
                    .frame(width: dot.size, height: dot.size)
                    .frame(width: 8, height: 8)
            }
        }
        .frame(width: 136, height: 20)
        .clipped()
        .animation(.easeInOut(duration: 0.18), value: homeAccountsPagerSelectedIndex)
        .animation(.easeInOut(duration: 0.18), value: homeAccountsPagerCount)
        .accessibilityLabel("Позиция \(homeAccountsPagerSelectedIndex + 1) из \(homeAccountsPagerCount)")
    }

    var homeAccountsCrossfadeAnimation: Animation {
        .easeInOut(duration: 0.28)
    }

    var homeAccountsPagerCount: Int {
        switch homeMainDisplayMode {
        case .focus:
            return max(1, homeMainAccounts.count)
        case .compact:
            return homeCompactPageCount
        }
    }

    var homeAccountsPagerSelectedIndex: Int {
        switch homeMainDisplayMode {
        case .focus:
            return min(focusedAccountIndex, homeAccountsPagerCount - 1)
        case .compact:
            return min(compactAccountsPageIndex, homeAccountsPagerCount - 1)
        }
    }

    var homeAccountsPagerDots: [HomeAccountsPagerDot] {
        let count = homeAccountsPagerCount
        guard count > 0 else { return [] }

        let maximumVisibleDots = 6
        guard count > maximumVisibleDots else {
            return (0..<count).map { index in
                HomeAccountsPagerDot(index: index, size: 8)
            }
        }

        let selectedIndex = homeAccountsPagerSelectedIndex
        let visibleStart = min(max(selectedIndex - 3, 0), count - maximumVisibleDots)
        let visibleEnd = visibleStart + maximumVisibleDots

        return (visibleStart..<visibleEnd).map { index in
            let position = index - visibleStart
            let hasItemsBefore = visibleStart > 0
            let hasItemsAfter = visibleEnd < count
            let size: CGFloat

            if hasItemsBefore && position == 0 {
                size = 4
            } else if hasItemsBefore && position == 1 {
                size = 6
            } else if hasItemsAfter && position == maximumVisibleDots - 2 {
                size = 6
            } else if hasItemsAfter && position == maximumVisibleDots - 1 {
                size = 4
            } else {
                size = 8
            }

            return HomeAccountsPagerDot(index: index, size: size)
        }
    }

    var homeAllAccounts: [Home8FocusAccount] {
        [
            .init(
                id: "black",
                title: homeAccountTitle(for: "black", defaultTitle: "Black"),
                balanceWithoutKopecks: "12 424 ₽",
                balanceWithKopecks: "12 424,31 ₽",
                badgeText: "305 ₽",
                cardStyle: .black,
                cardNumbers: ["4572", "4572"]
            ),
            .init(
                id: "platinum",
                title: homeAccountTitle(for: "platinum", defaultTitle: "Платинум"),
                balanceWithoutKopecks: "100 000 ₽",
                balanceWithKopecks: "100 000 ₽",
                badgeText: "1 783",
                cardStyle: .platinum,
                cardNumbers: ["4572"]
            ),
            .init(
                id: "savings",
                title: homeAccountTitle(for: "savings", defaultTitle: "Копилка"),
                balanceWithoutKopecks: "340 000 ₽",
                balanceWithKopecks: "340 000 ₽",
                badgeText: nil,
                cardStyle: .savings,
                cardNumbers: []
            ),
            .init(
                id: "rent",
                title: homeAccountTitle(for: "rent", defaultTitle: "Аренда"),
                balanceWithoutKopecks: "85 000 ₽",
                balanceWithKopecks: "85 000 ₽",
                badgeText: nil,
                cardStyle: .savings,
                cardNumbers: []
            ),
            .init(
                id: "month",
                title: homeAccountTitle(for: "month", defaultTitle: "На месяц"),
                balanceWithoutKopecks: "45 500 ₽",
                balanceWithKopecks: "45 500 ₽",
                badgeText: nil,
                cardStyle: .savings,
                cardNumbers: []
            ),
            .init(
                id: "japan",
                title: homeAccountTitle(for: "japan", defaultTitle: "Япония"),
                balanceWithoutKopecks: "210 000 ₽",
                balanceWithKopecks: "210 000 ₽",
                badgeText: nil,
                cardStyle: .savings,
                cardNumbers: []
            ),
            .init(
                id: "joint",
                title: homeAccountTitle(for: "joint", defaultTitle: "Совместный счет"),
                balanceWithoutKopecks: "32 004 ₽",
                balanceWithKopecks: "32 004,11 ₽",
                badgeText: nil,
                cardStyle: .joint,
                cardNumbers: []
            ),
            .init(
                id: "spendable",
                title: homeAccountTitle(for: "spendable", defaultTitle: "Могу тратить"),
                balanceWithoutKopecks: "12 125 ₽",
                balanceWithKopecks: "12 125 ₽",
                badgeText: nil,
                cardStyle: .wallet,
                cardNumbers: []
            )
        ]
    }

    var homeMainAccounts: [Home8FocusAccount] {
        let orderedAccounts = homeVisibleAccountIDs.compactMap(homeAccount)
        return orderedAccounts.isEmpty ? Array(homeAllAccounts.prefix(1)) : orderedAccounts
    }

    func homeAccount(for id: String) -> Home8FocusAccount? {
        homeAllAccounts.first { $0.id == id }
    }

    func homeAccountTitle(for id: String, defaultTitle: String) -> String {
        homeAccountTitleOverrides[id] ?? defaultTitle
    }

    func defaultHomeAccountTitle(for id: String) -> String? {
        switch id {
        case "black":
            return "Black"
        case "platinum":
            return "Платинум"
        case "savings":
            return "Копилка"
        case "rent":
            return "Аренда"
        case "month":
            return "На месяц"
        case "japan":
            return "Япония"
        case "joint":
            return "Совместный счет"
        case "spendable":
            return "Могу тратить"
        default:
            return nil
        }
    }

    func clampHomeAccountsNavigationState() {
        clampFocusedAccountIndex()
        clampCompactAccountsPageIndex()
        guard homeAccountsPagerCount <= 1 else { return }
        focusAccountDotsHideTask?.cancel()
        focusAccountDotsHideTask = nil
        isFocusAccountPagerVisible = false
    }

    func clampFocusedAccountIndex() {
        let maxIndex = max(0, homeMainAccounts.count - 1)
        guard focusedAccountIndex > maxIndex else { return }
        focusedAccountIndex = maxIndex
    }

    func clampCompactAccountsPageIndex() {
        let maxIndex = max(0, homeCompactPageCount - 1)
        guard compactAccountsPageIndex > maxIndex else { return }
        compactAccountsPageIndex = maxIndex
    }

    var homeFocusDotActiveColor: Color {
        colorScheme == .dark ? .white.opacity(0.92) : Color(hex: "333333")
    }

    var homeFocusDotInactiveColor: Color {
        colorScheme == .dark ? .white.opacity(0.22) : Color(hex: "001024").opacity(0.12)
    }

    func showFocusAccountDots() {
        guard homeAccountsPagerCount > 1 else { return }
        focusAccountDotsHideTask?.cancel()
        focusAccountDotsHideTask = nil

        guard !isFocusAccountPagerVisible else { return }
        withAnimation(homeAccountsCrossfadeAnimation) {
            isFocusAccountPagerVisible = true
        }
    }

    func scheduleFocusAccountDotsHide() {
        focusAccountDotsHideTask?.cancel()
        focusAccountDotsHideTask = Task {
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(homeAccountsCrossfadeAnimation) {
                    isFocusAccountPagerVisible = false
                }
                focusAccountDotsHideTask = nil
            }
        }
    }

    func settleFocusAccountDrag() {
        withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.86)) {
            focusAccountDragOffset = 0
        }
        scheduleFocusAccountDotsHide()
    }

    func settleCompactAccountsDrag() {
        withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.86)) {
            compactAccountsDragOffset = 0
            isHomeAccountsHorizontalSwipeActive = false
        }
        scheduleFocusAccountDotsHide()
    }

    func resetHomeAccountsDragState() {
        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.9)) {
            focusAccountDragOffset = 0
            compactAccountsDragOffset = 0
            isHomeAccountsHorizontalSwipeActive = false
        }
    }

    func playHomeAccountSwipeHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    var homeQuickActions: [Home8QuickAction] {
        [
            .init(title: "Пополнить", iconSystemName: "plus"),
            .init(title: "Сканировать", iconSystemName: "plus"),
            .init(title: "Перевести", iconSystemName: "plus"),
            .init(title: "Недавнее", iconSystemName: nil, glassShape: .roundedRect(cornerRadius: 20))
        ]
    }
}

// MARK: - Colors

private extension TestInAppView {
    var screenBackgroundColor: Color {
        colorScheme == .dark ? .black : Color(hex: "F8F8F8")
    }

    @ViewBuilder
    var contentBackgroundSurface: some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32)

        if colorScheme == .dark {
            shape
                .fill(Color.black)
                .overlay(alignment: .top) {
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: "1C1C1E").opacity(0.9), location: 0.030666),
                            .init(color: Color(hex: "1C1C1E").opacity(0.0), location: 0.96933)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 242)
                }
                .clipShape(shape)
        } else {
            shape.fill(Color(hex: "F8F8F8"))
        }
    }

    var contentBackgroundStyle: AnyShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color(hex: "1C1C1E"), Color(hex: "1C1C1E").opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        return AnyShapeStyle(Color(hex: "F8F8F8"))
    }
    var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : .white
    }
    var homeInsightCardBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : .white
    }
    var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color(hex: "333333")
    }
    var secondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.65) : Color(hex: "9299A2")
    }
    var homeControlTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.92) : Color(hex: "404040")
    }
    var homeCardPocketBlendColor: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : Color(hex: "F8F8F8")
    }
    var homeOperationsCardBadgeBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.04)
    }
    var homePositiveAmountStyle: AnyShapeStyle {
        AnyShapeStyle(
            LinearGradient(
                colors: [Color(hex: "20F192"), Color(hex: "1DD07E")],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    var islandBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : Color(hex: "F8F8F8")
    }
    var refreshPullBackdropColor: Color {
        colorScheme == .dark ? islandBackgroundColor : screenBackgroundColor
    }
    var iconBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.gray.opacity(0.1)
    }
    var closeButtonBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)
    }
}

// MARK: - Supporting types

enum Home8GlassShapeKind {
    case circle
    case capsule
    case roundedRect(cornerRadius: CGFloat)
}

struct Home8GlassButtonModifier: ViewModifier {
    let shape: Home8GlassShapeKind
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            glassEffectContent(content: content)
                .buttonStyle(.plain)
        } else {
            content
                .background(fallbackBackground)
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0 : 0.06),
                    radius: 18,
                    x: 0,
                    y: 6
                )
                .buttonStyle(.plain)
        }
    }

    @available(iOS 26.0, *)
    @ViewBuilder
    private func glassEffectContent(content: Content) -> some View {
        switch shape {
        case .circle:
            content.glassEffect(.regular.interactive(), in: Circle())
        case .capsule:
            content.glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
        case let .roundedRect(cornerRadius):
            content.glassEffect(
                .regular.interactive(),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        }
    }

    @ViewBuilder
    private var fallbackBackground: some View {
        switch shape {
        case .circle:
            Circle()
                .fill(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.55))
                .background(Circle().fill(.ultraThinMaterial))
                .overlay(
                    Circle().stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.10 : 0.45),
                                Color.white.opacity(colorScheme == .dark ? 0.04 : 0.20)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
                )
        case .capsule:
            Capsule(style: .continuous)
                .fill(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.55))
                .background(Capsule(style: .continuous).fill(.ultraThinMaterial))
                .overlay(
                    Capsule(style: .continuous).stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.10 : 0.45),
                                Color.white.opacity(colorScheme == .dark ? 0.04 : 0.20)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
                )
        case let .roundedRect(cornerRadius):
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.55))
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.10 : 0.45),
                                Color.white.opacity(colorScheme == .dark ? 0.04 : 0.20)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
                )
        }
    }
}

struct Home8ActionGlassButtonModifier: ViewModifier {
    let shape: Home8GlassShapeKind
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            nativeGlassContent(content)
        } else {
            content.background(fallbackBackground)
        }
    }

    @available(iOS 26.0, *)
    @ViewBuilder
    private func nativeGlassContent<V: View>(_ content: V) -> some View {
        switch shape {
        case .circle:
            nativeGlassContent(content, in: Circle())
        case .capsule:
            nativeGlassContent(content, in: Capsule(style: .continuous))
        case let .roundedRect(cornerRadius):
            nativeGlassContent(content, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    @available(iOS 26.0, *)
    @ViewBuilder
    private func nativeGlassContent<V: View, S: Shape>(_ content: V, in shape: S) -> some View {
        if colorScheme == .dark {
            content.glassEffect(.regular.interactive(), in: shape)
        } else {
            content.glassEffect(.regular.tint(Color.white.opacity(0.55)).interactive(), in: shape)
        }
    }

    @ViewBuilder
    private var fallbackBackground: some View {
        switch shape {
        case .circle:
            Circle()
                .fill(fallbackFillColor)
                .background(Circle().fill(.ultraThinMaterial))
        case .capsule:
            Capsule(style: .continuous)
                .fill(fallbackFillColor)
                .background(Capsule(style: .continuous).fill(.ultraThinMaterial))
        case let .roundedRect(cornerRadius):
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(fallbackFillColor)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        }
    }

    private var fallbackFillColor: Color {
        Color.white.opacity(colorScheme == .dark ? 0.10 : 0.55)
    }
}

struct Home8FocusAccount: Identifiable {
    static let defaultVisibleAccountIDs = [
        "black",
        "platinum",
        "savings",
        "rent",
        "month",
        "japan",
        "spendable"
    ]

    let id: String
    let title: String
    let balanceWithoutKopecks: String
    let balanceWithKopecks: String
    let badgeText: String?
    let cardStyle: Home8FocusCardStyle
    let cardNumbers: [String]

    func balance(kopecksHidden: Bool) -> String {
        kopecksHidden ? balanceWithoutKopecks : balanceWithKopecks
    }

    var defaultCompactEmoji: String {
        switch id {
        case "black":
            return "🦆"
        case "platinum":
            return "₽"
        case "savings":
            return "🐷"
        case "rent":
            return "🏠"
        case "month":
            return "📅"
        case "japan":
            return "🗻"
        case "joint":
            return "👥"
        case "spendable":
            return "💸"
        default:
            return cardStyle.compactEmoji
        }
    }

    var defaultCompactSystemIconName: String {
        switch id {
        case "black", "platinum":
            return "rublesign.circle.fill"
        case "savings", "rent":
            return "house.circle.fill"
        case "month":
            return "folder.circle.fill"
        case "joint":
            return "briefcase.circle.fill"
        case "japan":
            return "airplane.circle.fill"
        case "spendable":
            return "dollarsign.circle.fill"
        default:
            return "rublesign.circle.fill"
        }
    }
}

struct HomeAccountCompactAppearance: Equatable {
    static let systemIconPrefix = "__system_icon__:"

    var emoji: String
    var backgroundHex: String?

    static func `default`(for account: Home8FocusAccount) -> HomeAccountCompactAppearance {
        HomeAccountCompactAppearance(
            emoji: systemIconID(account.defaultCompactSystemIconName),
            backgroundHex: nil
        )
    }

    static func systemIconID(_ systemName: String) -> String {
        systemIconPrefix + systemName
    }

    func compactCardBackground(defaultColor: Color) -> Color {
        guard let backgroundHex else { return defaultColor }
        return Color(hex: backgroundHex)
    }

    var avatarBackgroundColor: Color {
        guard let backgroundHex else { return .white }
        return Color(hex: backgroundHex)
    }

    var avatarForegroundColor: Color {
        if usesSystemIcon {
            return backgroundHex == nil ? Color(hex: "428BF9") : .white
        }
        return backgroundHex == nil ? Color(hex: "333333") : .white
    }

    var systemIconName: String? {
        guard emoji.hasPrefix(Self.systemIconPrefix) else { return nil }
        return String(emoji.dropFirst(Self.systemIconPrefix.count))
    }

    var usesSystemIcon: Bool {
        systemIconName != nil
    }
}

private struct HomeAccountAppearanceSwatch: Identifiable {
    let id: String
    let hex: String?

    var color: Color {
        guard let hex else { return .white }
        return Color(hex: hex)
    }
}

private struct HomeAccountSystemEmoji: Identifiable {
    let systemName: String
    let accessibilityLabel: String

    var id: String {
        systemName
    }
}

struct HomeCompactAccountAppearanceEditorView: View {
    let account: Home8FocusAccount
    @Binding var accountName: String
    @Binding var appearance: HomeAccountCompactAppearance
    @Environment(\.dismiss) private var dismiss
    @State private var isEditingName = false
    @State private var renameChipFrame: CGRect = .zero
    @State private var renameOverlayChipFrame: CGRect = .zero

    private static let swatches: [HomeAccountAppearanceSwatch] = [
        .init(id: "white", hex: nil),
        .init(id: "red", hex: "FF2C5F"),
        .init(id: "pink", hex: "FF339B"),
        .init(id: "magenta", hex: "EB34F7"),
        .init(id: "purple", hex: "9F4FFE"),
        .init(id: "blue", hex: "0082FF"),
        .init(id: "sky", hex: "00B2FF"),
        .init(id: "teal", hex: "00BEC9"),
        .init(id: "green", hex: "00CA45"),
        .init(id: "lime", hex: "A9EB11"),
        .init(id: "yellow", hex: "F4B004"),
        .init(id: "orange", hex: "FE6702"),
        .init(id: "slate", hex: "5B6670"),
        .init(id: "dark", hex: "1C1C1E")
    ]

    private static let systemEmojis: [HomeAccountSystemEmoji] = [
        .init(systemName: "rublesign.circle.fill", accessibilityLabel: "Рубль"),
        .init(systemName: "house.circle.fill", accessibilityLabel: "Дом"),
        .init(systemName: "folder.circle.fill", accessibilityLabel: "Папка"),
        .init(systemName: "briefcase.circle.fill", accessibilityLabel: "Портфель"),
        .init(systemName: "airplane.circle.fill", accessibilityLabel: "Самолет"),
        .init(systemName: "dollarsign.circle.fill", accessibilityLabel: "Доллар")
    ]

    private static let emojis = [
        "🦆", "🐷", "🚃", "🪴", "🏠", "💸",
        "📅", "🗻", "👥", "✈️", "🎁", "⭐️",
        "🍕", "☕️", "🎮", "🎧", "📚", "🏖️",
        "🚗", "🛒", "💊", "🍿", "🎬", "🎯",
        "🏦", "💎", "⚡️", "🔥", "🌿", "🌈",
        "☀️", "🌙", "❄️", "🍀", "🌸", "🎈",
        "🚀", "🧳", "🪙", "💳", "🧾", "🔑",
        "🎒", "🧸", "🛟", "🏆", "🛵", "🍜",
        "🧃", "🥐", "🍣", "🎟️", "🎤", "🎹",
        "🏀", "⚽️", "🏋️", "🧘", "🏡", "🛠️",
        "💡", "📱", "💻", "⌚️", "🧁", "🍎",
        "🥑", "🚕", "🚲", "🛴", "🛫", "🧿"
    ]

    private static let compactPreviewCardHeight: CGFloat = 132
    private static let compactPreviewGridSpacing: CGFloat = 16
    private static let compactPreviewGridHorizontalInset: CGFloat = 2

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                editorContent
                    .blur(radius: isEditingName ? 16 : 0)
                    .opacity(isEditingName ? 0.34 : 1)

                if isEditingName {
                    HomeAccountNameEditorOverlay(
                        accountName: $accountName,
                        isPresented: $isEditingName,
                        sourceChipFrame: renameOverlayChipFrame
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .transition(
                        .asymmetric(
                            insertion: .opacity,
                            removal: .identity
                        )
                    )
                    .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.28), value: isEditingName)
            .onPreferenceChange(HomeRenameChipFramePreferenceKey.self) { frame in
                if !isEditingName && !frame.isEmpty {
                    renameChipFrame = frame
                }
            }
        }
        .background(Color.white)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Text("Готово")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.black)
                }
            }
        }
        .toolbar(isEditingName ? .hidden : .visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .preferredColorScheme(.light)
    }

    private var editorContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                accountPreviewCard
                    .padding(.top, 24)

                renameAccountChip
                    .padding(.top, 28)

                colorSelector
                    .padding(.top, 30)

                emojiPicker
                    .padding(.top, 20)
                    .padding(.bottom, 34)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private var accountPreviewCard: some View {
        GeometryReader { geometry in
            let cardWidth = max(
                (geometry.size.width - Self.compactPreviewGridHorizontalInset * 2 - Self.compactPreviewGridSpacing) / 2,
                0
            )

            accountPreviewCardContent
                .frame(width: cardWidth, height: Self.compactPreviewCardHeight, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(height: Self.compactPreviewCardHeight)
    }

    private var accountPreviewCardContent: some View {
        let isTinted = appearance.backgroundHex != nil
        let cardShape = RoundedRectangle(cornerRadius: 32, style: .continuous)

        return VStack(alignment: .leading, spacing: 0) {
            previewIcon
                .frame(height: 34, alignment: .topLeading)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text(account.balance(kopecksHidden: true))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .kerning(-0.41)
                    .foregroundColor(isTinted ? .white : Color(hex: "333333"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(accountName)
                    .font(.system(size: 15, weight: .regular))
                    .kerning(-0.24)
                    .foregroundColor(isTinted ? Color.white.opacity(0.86) : Color(hex: "9299A2"))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background {
            cardShape.fill(appearance.compactCardBackground(defaultColor: .white))
        }
        .clipShape(cardShape)
        .shadow(color: Color.black.opacity(isTinted ? 0 : 0.1), radius: 26, x: 0, y: 8)
    }

    private var renameAccountChip: some View {
        Button {
            startEditingName()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .medium))

                Text("Изменить название")
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(Color(hex: "333333"))
            .padding(.horizontal, 12)
            .frame(height: 38)
            .modifier(HomeAppearanceEditorChipBackgroundModifier())
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        key: HomeRenameChipFramePreferenceKey.self,
                        value: proxy.frame(in: .global)
                    )
            }
        )
        .buttonStyle(.plain)
        .opacity(isEditingName ? 0 : 1)
        .allowsHitTesting(!isEditingName)
        .accessibilityLabel("Изменить название")
    }

    @ViewBuilder
    private var previewIcon: some View {
        if let systemIconName = appearance.systemIconName {
            Image(systemName: systemIconName)
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(appearance.avatarForegroundColor)
                .frame(width: 34, height: 34, alignment: .topLeading)
        } else {
            Text(appearance.emoji)
                .font(.system(size: 32))
                .foregroundColor(appearance.avatarForegroundColor)
                .lineLimit(1)
                .frame(width: 34, height: 34, alignment: .topLeading)
        }
    }

    private func startEditingName() {
        renameOverlayChipFrame = renameChipFrame
        withAnimation(.easeInOut(duration: 0.46)) {
            isEditingName = true
        }
    }

    private var colorSelector: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 12
            let horizontalPadding: CGFloat = 16
            let availableWidth = geometry.size.width - horizontalPadding * 2
            let circleSize = (availableWidth - spacing * 6) / 7

            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    ForEach(Self.swatches.prefix(7)) { swatch in
                        colorChip(swatch, size: circleSize)
                    }
                }

                HStack(spacing: spacing) {
                    ForEach(Self.swatches.dropFirst(7)) { swatch in
                        colorChip(swatch, size: circleSize)
                    }
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, horizontalPadding)
        }
        .frame(height: 116)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func colorChip(_ swatch: HomeAccountAppearanceSwatch, size: CGFloat) -> some View {
        let isSelected = appearance.backgroundHex == swatch.hex

        return Button {
            playSelectionHaptic()
            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                appearance.backgroundHex = swatch.hex
            }
        } label: {
            ZStack {
                Circle()
                    .fill(swatch.color)
                    .frame(width: size, height: size)

                if swatch.hex == nil {
                    Circle()
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                        .frame(width: size, height: size)
                }

                if isSelected {
                    Circle()
                        .strokeBorder(swatch.hex == nil ? Color(hex: "333333") : .white, lineWidth: 3)
                        .frame(width: size - 6, height: size - 6)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(swatch.hex == nil ? "Белый" : "Цвет")
    }

    private var emojiPicker: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 12
            let horizontalPadding: CGFloat = 16
            let itemSize = (geometry.size.width - horizontalPadding * 2 - spacing * 5) / 6
            let columns = Array(repeating: GridItem(.fixed(itemSize), spacing: spacing), count: 6)

            ScrollView(.vertical, showsIndicators: true) {
                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach(Self.systemEmojis) { systemEmoji in
                        systemEmojiButton(systemEmoji, size: itemSize)
                    }

                    ForEach(Self.emojis, id: \.self) { emoji in
                        EmojiButton(
                            emoji: emoji,
                            isSelected: !appearance.usesSystemIcon && appearance.emoji == emoji,
                            size: itemSize
                        ) {
                            playSelectionHaptic()
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                                appearance.emoji = emoji
                            }
                        }
                    }
                }
                .padding(16)
            }
            .scrollIndicators(.visible)
            .background(Color.black.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .frame(height: 304)
        .frame(maxWidth: .infinity)
    }

    private func systemEmojiButton(_ systemEmoji: HomeAccountSystemEmoji, size: CGFloat) -> some View {
        let isSelected = appearance.systemIconName == systemEmoji.systemName

        return Button {
            playSelectionHaptic()
            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                appearance.emoji = HomeAccountCompactAppearance.systemIconID(systemEmoji.systemName)
            }
        } label: {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.white)
                        .frame(width: size, height: size)
                }

                Image(systemName: systemEmoji.systemName)
                    .font(.system(size: size * 0.66, weight: .semibold))
                    .foregroundColor(Color(hex: "428BF9"))
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(systemEmoji.accessibilityLabel)
    }

    private func playSelectionHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
}

private struct HomeRenameChipFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let nextFrame = nextValue()
        if !nextFrame.isEmpty {
            value = nextFrame
        }
    }
}

private struct HomeAccountNameEditorOverlay: View {
    @Binding var accountName: String
    @Binding var isPresented: Bool
    let sourceChipFrame: CGRect

    @FocusState private var isNameFocused: Bool
    @State private var draftName = ""
    @State private var controlsAreVisible = false
    @State private var nameFieldProgress: CGFloat = 0
    @State private var isClosing = false

    private var primaryTextColor: Color {
        Color(hex: "333333")
    }

    private var placeholderTextColor: Color {
        Color(hex: "9299A2").opacity(0.75)
    }

    var body: some View {
        GeometryReader { proxy in
            let overlayFrame = proxy.frame(in: .global)
            let nameCenterX = proxy.size.width / 2
            let nameCenterY = sourceChipFrame.isEmpty ? min(max(proxy.size.height * 0.255, 206), 236) : sourceChipFrame.midY - overlayFrame.minY

            ZStack {
                Color.white
                    .ignoresSafeArea()

                ZStack(alignment: .center) {
                    if draftName.isEmpty {
                        Text("Название")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(placeholderTextColor)
                            .tracking(-0.48)
                    }

                    TextField("", text: $draftName)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(primaryTextColor)
                        .tracking(-0.48)
                        .multilineTextAlignment(.center)
                        .focused($isNameFocused)
                        .submitLabel(.done)
                        .onSubmit(finishEditing)
                        .onChange(of: draftName) { _, newValue in
                            if newValue.count > 30 {
                                draftName = String(newValue.prefix(30))
                            }
                        }
                        .frame(maxWidth: 340)
                }
                .frame(height: 48)
                .opacity(0.45 + nameFieldProgress * 0.55)
                .scaleEffect(0.78 + nameFieldProgress * 0.22)
                .position(x: nameCenterX, y: nameCenterY)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack {
                Spacer(minLength: 0)

                Button {
                    finishEditing()
                } label: {
                    Text("Готово")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 112, height: 48)
                        .background {
                            Capsule(style: .continuous)
                                .fill(Color(hex: "428BF9"))
                        }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 21)
            .frame(height: 50)
            .padding(.bottom, 20)
            .opacity(controlsAreVisible ? 1 : 0)
            .offset(y: controlsAreVisible ? 0 : 72)
        }
        .onAppear {
            draftName = accountName

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isNameFocused = true
            }

            withAnimation(.interpolatingSpring(stiffness: 170, damping: 24).delay(0.04)) {
                nameFieldProgress = 1
            }

            withAnimation(.easeOut(duration: 0.34).delay(0.14)) {
                controlsAreVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            completeDismissAfterKeyboardHide()
        }
    }

    private func finishEditing() {
        guard !isClosing else {
            return
        }

        let trimmedName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            accountName = trimmedName
        }

        isClosing = true
        isNameFocused = false

        withAnimation(.easeInOut(duration: 0.3)) {
            controlsAreVisible = false
            nameFieldProgress = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.56) {
            if isClosing && isPresented {
                isPresented = false
            }
        }
    }

    private func completeDismissAfterKeyboardHide() {
        guard isClosing else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            if isClosing && isPresented {
                isPresented = false
            }
        }
    }
}

private struct HomeAppearanceEditorChipBackgroundModifier: ViewModifier {
    private let fillColor = Color.black.opacity(0.03)

    func body(content: Content) -> some View {
        content
            .background {
                Capsule(style: .continuous)
                    .fill(fillColor)
            }
    }
}

enum Home8MainDisplayMode: String, CaseIterable, Identifiable {
    case focus
    case compact

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .focus:
            return "Фокусный вид"
        case .compact:
            return "Компактный вид"
        }
    }
}

struct HomeAccountsPagerDot: Identifiable, Equatable {
    let index: Int
    let size: CGFloat

    var id: Int {
        index
    }
}

enum Home8FocusCardStyle {
    case black
    case platinum
    case savings
    case joint
    case wallet

    var compactSymbolName: String {
        switch self {
        case .black, .platinum, .joint:
            return "rublesign"
        case .savings:
            return "house.fill"
        case .wallet:
            return "wallet.pass.fill"
        }
    }

    var compactEmoji: String {
        switch self {
        case .black, .platinum, .joint:
            return "₽"
        case .savings:
            return "🏠"
        case .wallet:
            return "💸"
        }
    }
}

private struct Home8QuickAction: Identifiable {
    let id = UUID()
    let title: String
    let iconSystemName: String?
    let glassShape: Home8GlassShapeKind

    init(title: String, iconSystemName: String?, glassShape: Home8GlassShapeKind = .circle) {
        self.title = title
        self.iconSystemName = iconSystemName
        self.glassShape = glassShape
    }
}

private struct HomeRecentFolderItem: Identifiable {
    let id: String
    let title: String
    let assetName: String
}

private struct Home8PlusActionIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.08))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.08))
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.midY))
        return path
    }
}

private struct Home8ScanActionIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let inset = rect.width * 0.08
        let corner = rect.width * 0.28

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + inset, y: rect.minY + corner))
        path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.minY + inset))
        path.addLine(to: CGPoint(x: rect.minX + corner, y: rect.minY + inset))

        path.move(to: CGPoint(x: rect.maxX - corner, y: rect.minY + inset))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY + inset))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY + corner))

        path.move(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - corner))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - inset))
        path.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.maxY - inset))

        path.move(to: CGPoint(x: rect.minX + corner, y: rect.maxY - inset))
        path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.maxY - inset))
        path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.maxY - corner))
        return path
    }
}

private struct Home8ArrowActionIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.38, y: rect.minY + rect.height * 0.24))
        path.move(to: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.38, y: rect.maxY - rect.height * 0.24))
        return path
    }
}

struct Home8SavingsGraphLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.04, y: rect.minY + rect.height * 0.62))
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.minY + rect.height * 0.70),
            control1: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.72),
            control2: CGPoint(x: rect.minX + rect.width * 0.29, y: rect.minY + rect.height * 0.76)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.70, y: rect.minY + rect.height * 0.34),
            control1: CGPoint(x: rect.minX + rect.width * 0.52, y: rect.minY + rect.height * 0.64),
            control2: CGPoint(x: rect.minX + rect.width * 0.58, y: rect.minY + rect.height * 0.42)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.03, y: rect.minY + rect.height * 0.14),
            control1: CGPoint(x: rect.minX + rect.width * 0.80, y: rect.minY + rect.height * 0.28),
            control2: CGPoint(x: rect.minX + rect.width * 0.90, y: rect.minY + rect.height * 0.22)
        )
        return path
    }
}

struct Home8CardPocketShape: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(
                x: rect.minX + rect.width * x / 375,
                y: rect.minY + rect.height * y / 108
            )
        }

        var path = Path()
        path.move(to: point(139.77, 0.5))
        path.addCurve(
            to: point(155.871, 2.45801),
            control1: point(145.196, 0.500026),
            control2: point(150.603, 1.15719)
        )
        path.addLine(to: point(157.687, 2.90723))
        path.addCurve(
            to: point(219.226, 2.53613),
            control1: point(177.911, 7.90101),
            control2: point(199.062, 7.7733)
        )
        path.addCurve(
            to: point(235.162, 0.5),
            control1: point(224.43, 1.18437),
            control2: point(229.785, 0.500001)
        )
        path.addLine(to: point(374.5, 0.5))
        path.addLine(to: point(374.5, 107.5))
        path.addLine(to: point(0.5, 107.5))
        path.addLine(to: point(0.5, 0.5))
        path.closeSubpath()
        return path
    }
}

struct Home8CardPocketTopStrokeShape: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(
                x: rect.minX + rect.width * x / 375,
                y: rect.minY + rect.height * y / 108
            )
        }

        var path = Path()
        path.move(to: point(0.5, 0.5))
        path.addLine(to: point(139.77, 0.5))
        path.addCurve(
            to: point(155.871, 2.45801),
            control1: point(145.196, 0.500026),
            control2: point(150.603, 1.15719)
        )
        path.addLine(to: point(157.687, 2.90723))
        path.addCurve(
            to: point(219.226, 2.53613),
            control1: point(177.911, 7.90101),
            control2: point(199.062, 7.7733)
        )
        path.addCurve(
            to: point(235.162, 0.5),
            control1: point(224.43, 1.18437),
            control2: point(229.785, 0.500001)
        )
        path.addLine(to: point(374.5, 0.5))
        return path
    }
}

struct Home8CardPocketShadowShape: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(
                x: rect.minX + rect.width * x / 325.126,
                y: rect.minY + rect.height * y / 83.1372
            )
        }

        var path = Path()
        path.move(to: point(17.8151, 17.8151))
        path.addLine(to: point(124.764, 17.8151))
        path.addCurve(
            to: point(127.962, 18.1044),
            control1: point(125.836, 17.8151),
            control2: point(126.907, 17.9119)
        )
        path.addLine(to: point(159.365, 23.8342))
        path.addCurve(
            to: point(165.761, 23.8342),
            control1: point(161.48, 24.2199),
            control2: point(163.646, 24.2199)
        )
        path.addLine(to: point(197.164, 18.1044))
        path.addCurve(
            to: point(200.362, 17.8151),
            control1: point(198.219, 17.9119),
            control2: point(199.289, 17.8151)
        )
        path.addLine(to: point(307.311, 17.8151))
        path.addLine(to: point(307.311, 65.3221))
        path.addLine(to: point(17.8151, 65.3221))
        path.closeSubpath()
        return path
    }
}

struct Home8VisualEffectBlur: UIViewRepresentable {
    let style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ view: UIVisualEffectView, context: Context) {
        view.effect = UIBlurEffect(style: style)
    }
}

private struct Home8NotificationCard: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String?
    let iconSystemName: String?
}

private struct Home8ScalePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct Home8StablePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
    }
}

private enum Home8Tab: String, Identifiable {
    case main, payments, city, chat, showcase
    var id: String { rawValue }
    var title: String {
        switch self {
        case .main: return "Главная"
        case .payments: return "Платежи"
        case .city: return "Город"
        case .chat: return "Чат"
        case .showcase: return "Витрина"
        }
    }
    var symbolName: String {
        switch self {
        case .main: return "diamond.fill"
        case .payments: return "circle.fill"
        case .city: return "triangle.fill"
        case .chat: return "seal.fill"
        case .showcase: return "square.fill"
        }
    }
}

private struct Home8ScrollOffsetModifier: ViewModifier {
    @Binding var offset: CGFloat
    let allowsPositiveOffset: Bool

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { _, newValue in
                let nextOffset = -newValue
                let normalizedOffset = allowsPositiveOffset ? nextOffset : min(nextOffset, 0)
                guard abs(offset - normalizedOffset) >= 0.5 || (normalizedOffset == 0 && offset != 0) else { return }
                offset = normalizedOffset
            }
        } else {
            content
        }
    }
}

private struct Home8ScrollBounceModifier: ViewModifier {
    let isBounceEnabled: Bool

    func body(content: Content) -> some View {
        content.background(
            Home8ScrollBounceConfigurator(isBounceEnabled: isBounceEnabled)
                .frame(width: 0, height: 0)
        )
    }
}

private struct Home8ScrollBounceConfigurator: UIViewRepresentable {
    let isBounceEnabled: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        UIView(frame: .zero)
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let scrollView = context.coordinator.scrollView {
            context.coordinator.apply(isBounceEnabled, to: scrollView)
            return
        }
        let coordinator = context.coordinator
        let isBounceEnabled = isBounceEnabled
        DispatchQueue.main.async {
            guard let scrollView = uiView.enclosingScrollView else { return }
            coordinator.scrollView = scrollView
            coordinator.apply(isBounceEnabled, to: scrollView)
        }
    }

    final class Coordinator {
        weak var scrollView: UIScrollView?
        private var lastIsBounceEnabled: Bool?

        @MainActor
        func apply(_ isBounceEnabled: Bool, to scrollView: UIScrollView) {
            guard lastIsBounceEnabled != isBounceEnabled else { return }
            scrollView.bounces = isBounceEnabled
            scrollView.alwaysBounceVertical = isBounceEnabled
            lastIsBounceEnabled = isBounceEnabled
        }
    }
}

private extension UIView {
    var enclosingScrollView: UIScrollView? {
        if let scrollView = superview as? UIScrollView {
            return scrollView
        }
        return superview?.enclosingScrollView
    }
}

private struct Home8RefreshSpinner: UIViewRepresentable {
    let isAnimating: Bool

    func makeUIView(context: Context) -> UIActivityIndicatorView {
        let view = UIActivityIndicatorView(style: .medium)
        view.hidesWhenStopped = false
        view.color = UIColor.label.withAlphaComponent(0.75)
        return view
    }

    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {
        if isAnimating { uiView.startAnimating() }
        else { uiView.stopAnimating() }
    }
}

// MARK: - System Search

private struct Home8SystemSearchView: View {
    @Binding var searchText: String
    @State private var isSearchPresented = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
                    ContentUnavailableView(
                        "Системный поиск",
                        systemImage: "magnifyingglass",
                        description: Text("Начните ввод, чтобы проверить сценарий системного поиска.")
                    )
                } else {
                    List {
                        Text("Результаты для: \(searchText)")
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Поиск")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
        .searchable(
            text: $searchText,
            isPresented: $isSearchPresented,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Поиск"
        )
        .onAppear { isSearchPresented = true }
    }
}

// MARK: - Accounts Overview

struct HomeAccountsOverviewView: View {
    let allAccounts: [Home8FocusAccount]
    let accountAppearances: [String: HomeAccountCompactAppearance]
    @Binding var selectedIndex: Int
    @Binding var displayMode: Home8MainDisplayMode
    @Binding var areKopecksHidden: Bool
    @Binding var visibleAccountIDs: [String]
    @State private var isRecommendationVisible = true
    @State private var isEditingAccounts = false
    @State private var isAccountsReordering = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            accountsBackgroundColor.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if isEditingAccounts {
                        displayModeCard
                            .padding(.top, 24)
                            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))

                        hideKopecksCard
                            .padding(.top, 20)
                            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                    } else if isRecommendationVisible {
                        recommendationCard
                            .padding(.top, 24)
                            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                    }

                    HomeSettingsAccountsNativeReorderView(
                        allAccounts: allAccounts,
                        accountAppearances: accountAppearances,
                        areKopecksHidden: areKopecksHidden,
                        visibleAccountIDs: $visibleAccountIDs,
                        isReordering: $isAccountsReordering,
                        isEditingAccounts: isEditingAccounts,
                        onVisibleAccountSelect: selectVisibleAccount
                    )
                    .frame(height: accountsListHeight)
                    .padding(.top, accountsListTopPadding)
                    .animation(.spring(response: 0.34, dampingFraction: 0.88), value: isEditingAccounts)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 48)
            }
            .scrollDisabled(isAccountsReordering)
        }
        .navigationTitle(isEditingAccounts ? "Редактирование" : "Карты и счета")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    playLightSelectionHaptic()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                        isEditingAccounts.toggle()
                    }
                } label: {
                    Label(
                        isEditingAccounts ? "Готово" : "Редактировать",
                        systemImage: isEditingAccounts ? "checkmark" : "gearshape"
                    )
                        .labelStyle(.iconOnly)
                }
                .accessibilityLabel(isEditingAccounts ? "Готово" : "Редактировать")
            }
        }
        .toolbarBackground(accountsBackgroundColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var recommendationCard: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(accountsCardBackgroundColor)
                        .frame(width: 60, height: 88)
                        .overlay(alignment: .top) {
                            HStack(spacing: 6) {
                                Circle().fill(Color(hex: "428BF9")).frame(width: 5, height: 5)
                                Circle().fill(accountsSecondaryTextColor.opacity(0.22)).frame(width: 5, height: 5)
                                Circle().fill(accountsSecondaryTextColor.opacity(0.22)).frame(width: 5, height: 5)
                            }
                            .padding(.top, 10)
                        }
                        .overlay(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(accountsSecondaryTextColor.opacity(0.16))
                                .frame(width: 36, height: 12)
                                .padding(.bottom, 20)
                        }
                }
                .frame(width: 112, height: 112)

                Text("Можно сменить отображение\nГлавной на «Фокусное», оставить\nтолько важное")
                    .font(.system(size: 15, weight: .semibold))
                    .kerning(-0.24)
                    .foregroundColor(accountsPrimaryTextColor)
                    .multilineTextAlignment(.center)
                    .lineSpacing(1)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(accountsNeutralCardColor)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))

            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                    isRecommendationVisible = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(accountsSecondaryTextColor)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(accountsCardBackgroundColor))
            }
            .buttonStyle(.plain)
            .padding(16)
        }
        .padding(.horizontal, 16)
    }

    private func selectVisibleAccount(_ account: Home8FocusAccount) {
        guard !isEditingAccounts,
              let index = visibleAccounts.firstIndex(where: { $0.id == account.id }) else { return }
        selectedIndex = index
        dismiss()
    }

    private func accountCard(_ account: Home8FocusAccount) -> some View {
        Button {
            guard let index = visibleAccounts.firstIndex(where: { $0.id == account.id }) else { return }
            selectedIndex = index
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 16) {
                    accountAvatar(account)
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .center, spacing: 8) {
                            Text(account.balance(kopecksHidden: true))
                                .font(.system(size: 17, weight: .bold))
                                .kerning(-0.41)
                                .foregroundColor(accountsPrimaryTextColor)
                                .lineLimit(1)

                            Spacer(minLength: 8)

                            if let badgeText = account.badgeText {
                                accountBadge(text: badgeText, style: account.cardStyle)
                            }
                        }

                        Text(account.title)
                            .font(.system(size: 15, weight: .regular))
                            .kerning(-0.24)
                            .foregroundColor(accountsPrimaryTextColor)

                        if !account.cardNumbers.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(account.cardNumbers.indices, id: \.self) { cardIndex in
                                    accountCardThumbnail(account, number: account.cardNumbers[cardIndex], index: cardIndex)
                                }
                            }
                            .padding(.top, 12)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(accountsCardBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0 : 0.05),
                radius: 20,
                x: 0,
                y: 5
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func accountAvatar(_ account: Home8FocusAccount) -> some View {
        let appearance = accountAppearances[account.id]
        let effectiveAppearance = appearance ?? .default(for: account)
        let isDefaultAvatarSurface = effectiveAppearance.backgroundHex == nil
        let avatarSurfaceColor = effectiveAppearance.backgroundHex.map { Color(hex: $0) } ?? defaultAvatarSurfaceColor

        if let systemIconName = effectiveAppearance.systemIconName {
            Image(systemName: systemIconName)
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(effectiveAppearance.backgroundHex.map { Color(hex: $0) } ?? Color(hex: "428BF9"))
                .frame(width: 40, height: 40)
        } else {
            Circle()
                .fill(avatarSurfaceColor)
                .frame(width: 40, height: 40)
                .overlay {
                    Text(effectiveAppearance.emoji)
                        .font(.system(size: account.cardStyle == .platinum ? 20 : 24, weight: .bold, design: .rounded))
                        .foregroundColor(effectiveAppearance.backgroundHex == nil ? defaultAvatarTextColor : .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: 32, height: 32, alignment: .center)
                }
                .overlay {
                    if isDefaultAvatarSurface && colorScheme != .dark {
                        Circle()
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    }
                }
                .shadow(
                    color: Color.black.opacity(isDefaultAvatarSurface && colorScheme != .dark ? 0.08 : 0),
                    radius: 10,
                    x: 0,
                    y: 4
                )
        }
    }

    private var defaultAvatarSurfaceColor: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : .white
    }

    private var defaultAvatarTextColor: Color {
        colorScheme == .dark ? .white : Color(hex: "333333")
    }

    private func accountBadge(text: String, style: Home8FocusCardStyle) -> some View {
        HStack(spacing: 3) {
            Image(systemName: style == .black ? "crown.fill" : "sparkle")
                .font(.system(size: 8, weight: .bold))
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .kerning(-0.1)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .frame(height: 18)
        .background(
            Capsule(style: .continuous)
                .fill(style == .black ? Color(hex: "333333") : Color(hex: "747B8F"))
        )
    }

    private func accountCardThumbnail(_ account: Home8FocusAccount, number: String, index: Int) -> some View {
        ZStack(alignment: .bottomLeading) {
            switch account.cardStyle {
            case .black:
                Image("card")
                    .resizable()
                    .scaledToFill()
                    .saturation(index == 0 ? 1 : 0)
                    .brightness(index == 0 ? 0 : 0.08)
            case .platinum:
                Image("card")
                    .resizable()
                    .scaledToFill()
                    .saturation(0)
                    .brightness(0.18)
            case .savings:
                LinearGradient(
                    colors: [Color(hex: "7CAEFF"), Color(hex: "4972CF")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .joint, .wallet:
                LinearGradient(
                    colors: [Color(hex: "7CAEFF"), Color(hex: "4972CF")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            Text(number)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .padding(.leading, 4)
                .padding(.bottom, 3)
        }
        .frame(width: 48, height: 32)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    private var displayModeCard: some View {
        HStack(spacing: 28) {
            ForEach(Home8MainDisplayMode.allCases) { mode in
                let isSelected = displayMode == mode

                Button {
                    guard displayMode != mode else { return }
                    playLightSelectionHaptic()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                        displayMode = mode
                    }
                } label: {
                    VStack(spacing: 12) {
                        displayModePreview(mode, isSelected: isSelected)

                        displayModeChip(mode, isSelected: isSelected)
                    }
                    .frame(width: 135)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(accountsNeutralCardColor)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var hideKopecksCard: some View {
        Toggle(isOn: $areKopecksHidden) {
            Text("Скрыть копейки на главной")
                .font(.system(size: 17, weight: .regular))
                .kerning(-0.41)
                .foregroundColor(accountsPrimaryTextColor)
        }
        .tint(Color(hex: "428BF9"))
        .padding(.horizontal, 16)
        .frame(height: 68)
        .background(accountsNeutralCardColor)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 16)
    }

    private func displayModeChip(_ mode: Home8MainDisplayMode, isSelected: Bool) -> some View {
        Text(mode.title)
            .font(.system(size: 13, weight: .semibold))
            .kerning(-0.08)
            .foregroundColor(isSelected ? .white : accountsPrimaryTextColor)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(4)
            .padding(.horizontal, mode == .focus ? 7 : 8)
            .padding(.vertical, 3)
            .frame(minHeight: 30)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? Color(hex: "428BF9") : accountsNeutralCardColor)
            )
    }

    @ViewBuilder
    private func displayModePreview(_ mode: Home8MainDisplayMode, isSelected: Bool) -> some View {
        switch mode {
        case .focus:
            focusModePreview(isSelected: isSelected)
        case .compact:
            compactModePreview(isSelected: isSelected)
        }
    }

    private func focusModePreview(isSelected: Bool) -> some View {
        let activeColor = displayModePreviewColor(isSelected: isSelected)

        return ZStack(alignment: .topLeading) {
            HomeSettingsPreviewTopOutline()
                .stroke(activeColor, lineWidth: 2)
                .frame(width: 90, height: 121)

            Capsule(style: .continuous)
                .fill(activeColor)
                .frame(width: 25, height: 7)
                .offset(x: 32, y: 6)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "333333").opacity(0),
                            Color(hex: "333333").opacity(0.10),
                            Color(hex: "333333").opacity(0.10),
                            Color(hex: "333333").opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 86, height: 1)
                .offset(x: 2, y: 108)

            ForEach([12, 97, 169], id: \.self) { xOffset in
                focusModePage(color: activeColor)
                    .offset(x: CGFloat(xOffset), y: 0)
            }

            HStack(spacing: 3) {
                Circle().fill(activeColor).frame(width: 4, height: 4)
                Circle().fill(activeColor.opacity(0.35)).frame(width: 4, height: 4)
                Circle().fill(activeColor.opacity(0.35)).frame(width: 4, height: 4)
            }
            .offset(x: 37, y: 25)
        }
        .frame(width: 91, height: 121, alignment: .topLeading)
        .clipped()
    }

    private func focusModePage(color: Color) -> some View {
        ZStack(alignment: .topLeading) {
            Capsule(style: .continuous)
                .fill(color)
                .frame(width: 20, height: 6)
                .offset(x: 23, y: 42)

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color)
                .frame(width: 52, height: 12)
                .offset(x: 7, y: 52)

            UnevenRoundedRectangle(
                topLeadingRadius: 8,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 8,
                style: .continuous
            )
            .fill(color)
            .frame(width: 66, height: 28)
            .offset(x: 0, y: 80)
        }
        .frame(width: 66, height: 108, alignment: .topLeading)
    }

    private func compactModePreview(isSelected: Bool) -> some View {
        let activeColor = displayModePreviewColor(isSelected: isSelected)

        return ZStack(alignment: .topLeading) {
            HomeSettingsPreviewTopOutline()
                .stroke(activeColor, lineWidth: 2)
                .frame(width: 90, height: 121)

            Capsule(style: .continuous)
                .fill(activeColor)
                .frame(width: 25, height: 7)
                .offset(x: 32, y: 6)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(activeColor)
                .frame(width: 74, height: 68)
                .offset(x: 96.5, y: 28)

            ForEach(Array(compactPreviewCardOrigins.enumerated()), id: \.offset) { _, origin in
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(activeColor)
                    .frame(width: 35, height: 32)
                    .overlay(alignment: .bottom) {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.30))
                            .frame(width: 22, height: 5)
                            .padding(.bottom, 5)
                    }
                    .offset(x: origin.x, y: origin.y)
            }

            HStack(spacing: 3) {
                Circle().fill(activeColor.opacity(0.55)).frame(width: 4, height: 4)
                Circle().fill(activeColor.opacity(0.30)).frame(width: 4, height: 4)
            }
            .offset(x: 40, y: 104)
        }
        .frame(width: 90, height: 121, alignment: .topLeading)
        .clipped()
    }

    private var compactPreviewCardOrigins: [CGPoint] {
        [
            CGPoint(x: 8, y: 28),
            CGPoint(x: 47, y: 28),
            CGPoint(x: 8, y: 64),
            CGPoint(x: 47, y: 64)
        ]
    }

    private func displayModePreviewColor(isSelected: Bool) -> Color {
        isSelected ? Color(hex: "428BF9") : accountsTertiaryTextColor
    }

    private var accountsListTopPadding: CGFloat {
        20
    }

    private var accountsListHeight: CGFloat {
        let visibleCardsHeight = sectionCardsHeight(accounts: visibleAccounts)
        let mainSectionBottomGap: CGFloat = otherAccounts.isEmpty ? 0 : 20
        let mainActionHeight: CGFloat = isEditingAccounts ? (visibleCardsHeight > 0 ? 20 + 80 : 80) : 0
        let mainSectionHeight: CGFloat = 40 + 4 + visibleCardsHeight + mainActionHeight + mainSectionBottomGap
        let otherSectionHeight: CGFloat = otherAccounts.isEmpty ? 0 : 40 + 4 + sectionCardsHeight(accounts: otherAccounts)
        return mainSectionHeight + otherSectionHeight
    }

    private func sectionCardsHeight(accounts: [Home8FocusAccount]) -> CGFloat {
        guard !accounts.isEmpty else { return 0 }

        let cardsHeight = accounts.reduce(CGFloat.zero) { total, account in
            total + accountCellHeight(account)
        }
        return cardsHeight + CGFloat(accounts.count - 1) * 20
    }

    private func accountCellHeight(_ account: Home8FocusAccount) -> CGFloat {
        if isEditingAccounts {
            return HomeSettingsAccountMetrics.cardHeight
        }
        return account.cardNumbers.isEmpty ? HomeSettingsAccountMetrics.cardHeight : HomeSettingsAccountMetrics.overviewCardHeight
    }

    private var visibleAccounts: [Home8FocusAccount] {
        let accounts = visibleAccountIDs.compactMap { id in
            allAccounts.first { $0.id == id }
        }
        return accounts.isEmpty ? Array(allAccounts.prefix(1)) : accounts
    }

    private var otherAccounts: [Home8FocusAccount] {
        allAccounts.filter { account in
            !visibleAccountIDs.contains(account.id)
        }
    }

    private func playLightSelectionHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    private var accountsBackgroundColor: Color {
        colorScheme == .dark ? .black : Color(hex: "F8F8F8")
    }

    private var accountsCardBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : .white
    }

    private var accountsNeutralCardColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color(hex: "001024").opacity(0.06)
    }

    private var accountsPrimaryTextColor: Color {
        colorScheme == .dark ? .white : Color(hex: "333333")
    }

    private var accountsSecondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.58) : Color(hex: "9299A2")
    }

    private var accountsTertiaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.30) : Color(hex: "001024").opacity(0.22)
    }
}

private struct HomeSettingsPreviewTopOutline: Shape {
    func path(in rect: CGRect) -> Path {
        let lineInset: CGFloat = 1
        let radius: CGFloat = 16 - lineInset
        let minX = rect.minX + lineInset
        let maxX = rect.maxX - lineInset
        let minY = rect.minY + lineInset
        let maxY = rect.maxY
        var path = Path()
        path.move(to: CGPoint(x: minX, y: maxY))
        path.addLine(to: CGPoint(x: minX, y: minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: minX + radius, y: minY),
            control: CGPoint(x: minX, y: minY)
        )
        path.addLine(to: CGPoint(x: maxX - radius, y: minY))
        path.addQuadCurve(
            to: CGPoint(x: maxX, y: minY + radius),
            control: CGPoint(x: maxX, y: minY)
        )
        path.addLine(to: CGPoint(x: maxX, y: maxY))
        return path
    }
}

private enum HomeSettingsAccountMetrics {
    static let cardHeight: CGFloat = 80
    static let overviewCardHeight: CGFloat = 128
}

private struct HomeSettingsAccountsNativeReorderView: UIViewControllerRepresentable {
    let allAccounts: [Home8FocusAccount]
    let accountAppearances: [String: HomeAccountCompactAppearance]
    let areKopecksHidden: Bool
    @Binding var visibleAccountIDs: [String]
    @Binding var isReordering: Bool
    let isEditingAccounts: Bool
    let onVisibleAccountSelect: (Home8FocusAccount) -> Void

    func makeUIViewController(context: Context) -> HomeSettingsAccountsReorderViewController {
        let controller = HomeSettingsAccountsReorderViewController()
        controller.onVisibleAccountIDsChange = { nextIDs in
            visibleAccountIDs = nextIDs
        }
        controller.onReorderingStateChange = { isActive in
            isReordering = isActive
        }
        controller.onVisibleAccountSelect = onVisibleAccountSelect
        controller.update(
            allAccounts: allAccounts,
            accountAppearances: accountAppearances,
            visibleAccountIDs: visibleAccountIDs,
            areKopecksHidden: areKopecksHidden,
            isEditingAccounts: isEditingAccounts
        )
        return controller
    }

    func updateUIViewController(_ controller: HomeSettingsAccountsReorderViewController, context: Context) {
        controller.onVisibleAccountIDsChange = { nextIDs in
            visibleAccountIDs = nextIDs
        }
        controller.onReorderingStateChange = { isActive in
            isReordering = isActive
        }
        controller.onVisibleAccountSelect = onVisibleAccountSelect
        controller.update(
            allAccounts: allAccounts,
            accountAppearances: accountAppearances,
            visibleAccountIDs: visibleAccountIDs,
            areKopecksHidden: areKopecksHidden,
            isEditingAccounts: isEditingAccounts
        )
    }
}

private final class HomeSettingsAccountsReorderViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate {
    private enum Section: Int, CaseIterable {
        case main
        case other

        var index: Int {
            rawValue
        }
    }

    private let accountCellReuseID = "HomeSettingsAccountCell"
    private let clueCellReuseID = "HomeSettingsClueCell"
    private let headerReuseID = "HomeSettingsHeader"
    private var allAccounts: [Home8FocusAccount] = []
    private var accountAppearances: [String: HomeAccountCompactAppearance] = [:]
    private var visibleAccountIDs: [String] = []
    private var hiddenAccountIDs: [String] = []
    private var areKopecksHidden = true
    private var isEditingAccounts = false
    private var pendingVisibleAccountIDsChangeTask: DispatchWorkItem?
    private var isInteractiveMovementActive = false
    private var interactiveMovementLockedX: CGFloat?
    private var activeMovementSourceID: String?
    private var activeMovementSourceSection: Section?
    private var lastInteractiveMovementLocation: CGPoint = .zero
    private var needsPostMoveReload = false
    private let editingState = HomeAccountEditingState()
    private var pendingEditingLayoutWork: DispatchWorkItem?
    private var pendingEditingRevealWork: DispatchWorkItem?
    var onVisibleAccountIDsChange: (([String]) -> Void)?
    var onReorderingStateChange: ((Bool) -> Void)?
    var onVisibleAccountSelect: ((Home8FocusAccount) -> Void)?

    private lazy var handlePanGesture: UIPanGestureRecognizer = {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handleHandlePan(_:)))
        gesture.maximumNumberOfTouches = 1
        gesture.cancelsTouchesInView = true
        gesture.delegate = self
        return gesture
    }()

    init() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 20
        layout.minimumInteritemSpacing = 20
        layout.estimatedItemSize = .zero
        super.init(collectionViewLayout: layout)
        installsStandardGestureForInteractiveMovement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = false
        collectionView.clipsToBounds = false
        collectionView.addGestureRecognizer(handlePanGesture)
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: accountCellReuseID)
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: clueCellReuseID)
        collectionView.register(
            HomeSettingsHostingReusableView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: headerReuseID
        )
        collectionView.register(
            HomeSettingsHostingReusableView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
            withReuseIdentifier: headerReuseID
        )
    }

    func update(
        allAccounts: [Home8FocusAccount],
        accountAppearances: [String: HomeAccountCompactAppearance],
        visibleAccountIDs: [String],
        areKopecksHidden: Bool,
        isEditingAccounts: Bool
    ) {
        let allAccountIDs = allAccounts.map(\.id)
        let allAccountIDSet = Set(allAccountIDs)
        let normalizedVisibleAccountIDs = (visibleAccountIDs.isEmpty ? Array(allAccountIDs.prefix(1)) : visibleAccountIDs)
            .filter { allAccountIDSet.contains($0) }
        let safeVisibleAccountIDs = normalizedVisibleAccountIDs.isEmpty ? Array(allAccountIDs.prefix(1)) : normalizedVisibleAccountIDs
        let visibleAccountIDSet = Set(safeVisibleAccountIDs)
        let preservedHiddenAccountIDs = hiddenAccountIDs.filter { allAccountIDSet.contains($0) && !visibleAccountIDSet.contains($0) }
        let missingHiddenAccountIDs = allAccountIDs.filter { !visibleAccountIDSet.contains($0) && !preservedHiddenAccountIDs.contains($0) }
        let nextHiddenAccountIDs = preservedHiddenAccountIDs + missingHiddenAccountIDs
        let dataChanged = self.allAccounts.map(\.id) != allAccounts.map(\.id)
            || self.accountAppearances != accountAppearances
            || self.visibleAccountIDs != safeVisibleAccountIDs
            || self.hiddenAccountIDs != nextHiddenAccountIDs
            || self.areKopecksHidden != areKopecksHidden
        let editingToggled = self.isEditingAccounts != isEditingAccounts
        let shouldReload = dataChanged || editingToggled

        let previousVisibleCount = visibleAccounts.count

        self.allAccounts = allAccounts
        self.accountAppearances = accountAppearances
        self.visibleAccountIDs = safeVisibleAccountIDs
        self.hiddenAccountIDs = nextHiddenAccountIDs
        self.areKopecksHidden = areKopecksHidden
        self.isEditingAccounts = isEditingAccounts
        let nextAreKopecksHidden = areKopecksHidden
        DispatchQueue.main.async { self.editingState.areKopecksHidden = nextAreKopecksHidden }
        guard isViewLoaded, shouldReload else { return }

        if editingToggled && !dataChanged {
            animateEditingToggle(
                isEditingAccounts: isEditingAccounts,
                previousVisibleCount: previousVisibleCount
            )
            return
        }

        cancelPendingEditingWork()
        DispatchQueue.main.async {
            self.editingState.isEditing = isEditingAccounts
            self.editingState.decorationsHidden = isEditingAccounts
            self.editingState.dragHandleVisible = isEditingAccounts
        }
        collectionView.collectionViewLayout.invalidateLayout()
        UIView.animate(
            withDuration: 0.24,
            delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            self.collectionView.reloadData()
            self.collectionView.layoutIfNeeded()
        }
    }

    private func cancelPendingEditingWork() {
        pendingEditingLayoutWork?.cancel()
        pendingEditingRevealWork?.cancel()
        pendingEditingLayoutWork = nil
        pendingEditingRevealWork = nil
    }

    private func animateEditingToggle(
        isEditingAccounts: Bool,
        previousVisibleCount: Int
    ) {
        cancelPendingEditingWork()

        let mainSection = Section.main.index
        let placeholderIndexPath = IndexPath(item: previousVisibleCount, section: mainSection)
        // Фазы перекрываются: layout стартует до завершения fade → ощущается снапперным
        let fadeStart: TimeInterval = 0.00
        let layoutStart: TimeInterval = 0.05   // перекрытие с fade
        let revealStart: TimeInterval = 0.26   // после того как spring прошёл 80% пути

        if isEditingAccounts {
            // Forward: hide decorations → shrink layout (overlap) → reveal drag handle
            DispatchQueue.main.asyncAfter(deadline: .now() + fadeStart) {
                self.editingState.decorationsHidden = true
            }

            let layoutWork = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.collectionView.performBatchUpdates({
                    self.editingState.isEditing = true
                    self.collectionView.insertItems(at: [placeholderIndexPath])
                }, completion: nil)
            }
            let revealWork = DispatchWorkItem { [weak self] in
                self?.editingState.dragHandleVisible = true
            }
            pendingEditingLayoutWork = layoutWork
            pendingEditingRevealWork = revealWork
            DispatchQueue.main.asyncAfter(deadline: .now() + layoutStart, execute: layoutWork)
            DispatchQueue.main.asyncAfter(deadline: .now() + revealStart, execute: revealWork)
        } else {
            // Reverse: hide drag handle → grow layout (overlap) → reveal decorations
            DispatchQueue.main.asyncAfter(deadline: .now() + fadeStart) {
                self.editingState.dragHandleVisible = false
            }

            let layoutWork = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.collectionView.performBatchUpdates({
                    self.editingState.isEditing = false
                    self.collectionView.deleteItems(at: [placeholderIndexPath])
                }, completion: nil)
            }
            let revealWork = DispatchWorkItem { [weak self] in
                self?.editingState.decorationsHidden = false
            }
            pendingEditingLayoutWork = layoutWork
            pendingEditingRevealWork = revealWork
            DispatchQueue.main.asyncAfter(deadline: .now() + layoutStart, execute: layoutWork)
            DispatchQueue.main.asyncAfter(deadline: .now() + revealStart, execute: revealWork)
        }
    }

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        Section.allCases.count
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .main:
            return visibleAccounts.count + (isEditingAccounts ? 1 : 0)
        case .other:
            return otherAccounts.count
        case nil:
            return 0
        }
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let isClue = isMainActionIndexPath(indexPath)
        let reuseID = isClue ? clueCellReuseID : accountCellReuseID
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseID, for: indexPath)
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        cell.clipsToBounds = false
        cell.contentView.clipsToBounds = false

        if isClue {
            cell.contentConfiguration = UIHostingConfiguration {
                HomeSettingsReorderClueCard(isRestoreHint: !otherAccounts.isEmpty)
            }
            .margins(.all, 0)
            cell.layer.zPosition = 0
            return cell
        }

        guard let account = account(at: indexPath) else {
            cell.contentConfiguration = nil
            cell.layer.zPosition = 0
            return cell
        }
        cell.contentConfiguration = UIHostingConfiguration {
            HomeAccountMorphCard(
                account: account,
                appearance: accountAppearances[account.id],
                state: editingState
            )
        }
        .margins(.all, 0)
        cell.layer.zPosition = 2
        return cell
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let view = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: headerReuseID,
                for: indexPath
            )
            guard let view = view as? HomeSettingsHostingReusableView else { return view }
            let title = Section(rawValue: indexPath.section) == .main ? "НА ГЛАВНОЙ" : "ОСТАЛЬНЫЕ СЧЕТА"
            view.configure {
                HomeSettingsSectionHeader(title: title)
            }
            return view
        }

        return collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: headerReuseID,
            for: indexPath
        )
    }

    override func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        canMoveAccount(at: indexPath)
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard !isEditingAccounts,
              Section(rawValue: indexPath.section) == .main,
              let account = account(at: indexPath) else { return }
        onVisibleAccountSelect?(account)
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        moveItemAt sourceIndexPath: IndexPath,
        to destinationIndexPath: IndexPath
    ) {
        moveAccount(
            from: sourceIndexPath,
            to: destinationIndexPath,
            isActionDrop: false
        )
    }

    private func moveAccount(from sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath, isActionDrop: Bool) {
        guard let sourceID = accountID(at: sourceIndexPath),
              let sourceSection = Section(rawValue: sourceIndexPath.section),
              let destinationSection = Section(rawValue: destinationIndexPath.section) else { return }
        moveAccount(
            sourceID: sourceID,
            sourceSection: sourceSection,
            destinationIndexPath: destinationIndexPath,
            destinationSection: destinationSection,
            isActionDrop: isActionDrop
        )
    }

    private func moveAccount(
        sourceID: String,
        sourceSection: Section,
        destinationIndexPath: IndexPath,
        destinationSection: Section,
        isActionDrop: Bool
    ) {
        if sourceSection == .main, destinationSection == .other, visibleAccounts.count <= 1 {
            return
        }

        let previousVisibleAccountIDs = visibleAccountIDs
        var nextVisibleAccountIDs = visibleAccountIDs.filter { $0 != sourceID }
        var nextHiddenAccountIDs = hiddenAccountIDs.filter { $0 != sourceID }

        switch destinationSection {
        case .main:
            let insertionIndex = isActionDrop
                && sourceSection == .other
                ? nextVisibleAccountIDs.count
                : min(max(destinationIndexPath.item, 0), nextVisibleAccountIDs.count)
            nextVisibleAccountIDs.insert(sourceID, at: insertionIndex)
        case .other:
            let insertionIndex = isActionDrop
                && sourceSection == .main
                ? nextHiddenAccountIDs.count
                : min(max(destinationIndexPath.item, 0), nextHiddenAccountIDs.count)
            nextHiddenAccountIDs.insert(sourceID, at: insertionIndex)
        }

        guard !nextVisibleAccountIDs.isEmpty else { return }
        visibleAccountIDs = nextVisibleAccountIDs
        hiddenAccountIDs = nextHiddenAccountIDs
        needsPostMoveReload = true
        guard nextVisibleAccountIDs != previousVisibleAccountIDs else { return }
        pendingVisibleAccountIDsChangeTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.onVisibleAccountIDsChange?(nextVisibleAccountIDs)
        }
        pendingVisibleAccountIDsChangeTask = task
        DispatchQueue.main.async(execute: task)
    }

    private func performActionDropMove(
        sourceID: String,
        sourceSection: Section,
        destinationIndexPath: IndexPath,
        destinationSection: Section
    ) {
        if sourceSection == .main, destinationSection == .other, visibleAccounts.count <= 1 {
            return
        }

        let previousVisibleAccountIDs = visibleAccountIDs
        let previousHiddenAccountIDs = hiddenAccountIDs
        let sourceIndexPath = indexPath(for: sourceID, in: sourceSection)
        let destinationInsertIndex = destinationSection == .main
            ? visibleAccountIDs.filter { $0 != sourceID }.count
            : hiddenAccountIDs.filter { $0 != sourceID }.count

        var nextVisibleAccountIDs = visibleAccountIDs.filter { $0 != sourceID }
        var nextHiddenAccountIDs = hiddenAccountIDs.filter { $0 != sourceID }

        switch destinationSection {
        case .main:
            nextVisibleAccountIDs.insert(sourceID, at: min(destinationInsertIndex, nextVisibleAccountIDs.count))
        case .other:
            nextHiddenAccountIDs.insert(sourceID, at: min(destinationInsertIndex, nextHiddenAccountIDs.count))
        }

        guard !nextVisibleAccountIDs.isEmpty else { return }
        let destinationInsertedIndexPath = IndexPath(item: destinationInsertIndex, section: destinationSection.index)
        let shouldRefreshHintText = previousHiddenAccountIDs.isEmpty != nextHiddenAccountIDs.isEmpty
        visibleAccountIDs = nextVisibleAccountIDs
        hiddenAccountIDs = nextHiddenAccountIDs
        playActionDropImpact()

        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.performBatchUpdates {
            if let sourceIndexPath {
                collectionView.deleteItems(at: [sourceIndexPath])
            }
            if sourceSection != destinationSection {
                collectionView.insertItems(at: [destinationInsertedIndexPath])
            }
        } completion: { [weak self] _ in
            guard let self else { return }
            UIView.animate(
                withDuration: 0.28,
                delay: 0,
                usingSpringWithDamping: 0.86,
                initialSpringVelocity: 0.2,
                options: [.beginFromCurrentState, .allowUserInteraction]
            ) {
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.layoutIfNeeded()
            } completion: { _ in
                guard shouldRefreshHintText else { return }
                UIView.transition(
                    with: self.collectionView,
                    duration: 0.18,
                    options: [.transitionCrossDissolve, .allowUserInteraction]
                ) {
                    self.collectionView.reloadItems(at: [self.mainActionIndexPath])
                    self.collectionView.reloadSections(IndexSet(integer: Section.other.index))
                }
            }
        }

        guard nextVisibleAccountIDs != previousVisibleAccountIDs else { return }
        pendingVisibleAccountIDsChangeTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.onVisibleAccountIDsChange?(nextVisibleAccountIDs)
        }
        pendingVisibleAccountIDsChangeTask = task
        DispatchQueue.main.async(execute: task)
    }

    private func playActionDropImpact() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred(intensity: 0.72)
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        targetIndexPathForMoveFromItemAt originalIndexPath: IndexPath,
        toProposedIndexPath proposedIndexPath: IndexPath
    ) -> IndexPath {
        guard let sourceSection = Section(rawValue: originalIndexPath.section),
              let proposedSection = Section(rawValue: proposedIndexPath.section) else { return originalIndexPath }
        if isMainActionIndexPath(proposedIndexPath) || isPointInsideMainActionDropZone(lastInteractiveMovementLocation) {
            guard mainActionDropDestination(for: sourceSection) != nil else { return originalIndexPath }
            return originalIndexPath
        }

        if sourceSection == .main,
           proposedSection == .other,
           visibleAccounts.count <= 1 {
            return originalIndexPath
        }

        if proposedSection == .other, otherAccounts.isEmpty {
            return originalIndexPath
        }

        let maximumItem = maximumDestinationItem(in: proposedSection, movingFrom: sourceSection)
        return IndexPath(
            item: min(max(proposedIndexPath.item, 0), maximumItem),
            section: proposedSection.index
        )
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        guard account(at: indexPath) != nil else {
            if isEditingAccounts, isMainActionIndexPath(indexPath) {
                return CGSize(width: max(0, collectionView.bounds.width - 32), height: 80)
            }
            return CGSize(width: max(0, collectionView.bounds.width - 32), height: 0)
        }
        if !isEditingAccounts, let account = account(at: indexPath) {
            let height = account.cardNumbers.isEmpty
                ? HomeSettingsAccountMetrics.cardHeight
                : HomeSettingsAccountMetrics.overviewCardHeight
            return CGSize(width: max(0, collectionView.bounds.width - 32), height: height)
        }
        return CGSize(
            width: max(0, collectionView.bounds.width - 32),
            height: HomeSettingsAccountMetrics.cardHeight
        )
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        insetForSectionAt section: Int
    ) -> UIEdgeInsets {
        if section == Section.other.index, otherAccounts.isEmpty {
            return .zero
        }
        let bottomInset: CGFloat = section == Section.main.index && !otherAccounts.isEmpty ? 20 : 0
        return UIEdgeInsets(top: 4, left: 16, bottom: bottomInset, right: 16)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        referenceSizeForHeaderInSection section: Int
    ) -> CGSize {
        if section == Section.other.index, otherAccounts.isEmpty {
            return .zero
        }
        return CGSize(width: collectionView.bounds.width, height: 40)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        referenceSizeForFooterInSection section: Int
    ) -> CGSize {
        return .zero
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let location = gestureRecognizer.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: location), canMoveAccount(at: indexPath) else {
            return false
        }

        guard gestureRecognizer === handlePanGesture else { return false }
        let velocity = handlePanGesture.velocity(in: collectionView)
        return isHandleHit(at: location, indexPath: indexPath) && abs(velocity.y) >= abs(velocity.x) * 0.35
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        false
    }

    @objc private func handleHandlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: collectionView)

        switch gesture.state {
        case .began:
            beginInteractiveMovement(at: location)
        case .changed:
            updateInteractiveMovement(to: location)
        case .ended:
            endInteractiveMovement()
        case .cancelled, .failed:
            cancelInteractiveMovement()
        default:
            break
        }
    }

    private func beginInteractiveMovement(at location: CGPoint) {
        guard !isInteractiveMovementActive, let indexPath = collectionView.indexPathForItem(at: location) else { return }
        guard let sourceID = accountID(at: indexPath),
              let sourceSection = Section(rawValue: indexPath.section) else { return }
        guard collectionView.beginInteractiveMovementForItem(at: indexPath) else { return }
        let cell = collectionView.cellForItem(at: indexPath)
        interactiveMovementLockedX = cell?.center.x ?? collectionView.bounds.midX
        activeMovementSourceID = sourceID
        activeMovementSourceSection = sourceSection
        lastInteractiveMovementLocation = location
        isInteractiveMovementActive = true
        collectionView.updateInteractiveMovementTargetPosition(lockedMovementPoint(for: location))
        onReorderingStateChange?(true)
    }

    private func updateInteractiveMovement(to location: CGPoint) {
        guard isInteractiveMovementActive else { return }
        lastInteractiveMovementLocation = location
        collectionView.updateInteractiveMovementTargetPosition(lockedMovementPoint(for: location))
        refreshInteractiveMovementLayout()
    }

    private func refreshInteractiveMovementLayout() {
        collectionView.collectionViewLayout.invalidateLayout()
        UIView.performWithoutAnimation {
            collectionView.layoutIfNeeded()
        }
    }

    private func endInteractiveMovement() {
        guard isInteractiveMovementActive else { return }
        if let sourceID = activeMovementSourceID,
           let sourceSection = activeMovementSourceSection,
           isPointInsideMainActionDropZone(lastInteractiveMovementLocation),
           let destinationIndexPath = mainActionDropDestination(for: sourceSection) {
            collectionView.cancelInteractiveMovement()
            guard let destinationSection = Section(rawValue: destinationIndexPath.section) else {
                finishInteractiveMovement()
                return
            }
            performActionDropMove(
                sourceID: sourceID,
                sourceSection: sourceSection,
                destinationIndexPath: destinationIndexPath,
                destinationSection: destinationSection
            )
            finishInteractiveMovement()
            return
        }
        collectionView.endInteractiveMovement()
        finishInteractiveMovement()
    }

    private func cancelInteractiveMovement() {
        guard isInteractiveMovementActive else { return }
        collectionView.cancelInteractiveMovement()
        finishInteractiveMovement()
    }

    private func finishInteractiveMovement() {
        isInteractiveMovementActive = false
        interactiveMovementLockedX = nil
        activeMovementSourceID = nil
        activeMovementSourceSection = nil
        let shouldReload = needsPostMoveReload
        needsPostMoveReload = false
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if shouldReload {
                self.collectionView.collectionViewLayout.invalidateLayout()
                UIView.performWithoutAnimation {
                    self.collectionView.reloadData()
                    self.collectionView.layoutIfNeeded()
                }
            }
            self.onReorderingStateChange?(false)
        }
    }

    private func isHandleHit(at location: CGPoint, indexPath: IndexPath) -> Bool {
        guard let cell = collectionView.cellForItem(at: indexPath) else { return false }
        return location.x >= cell.frame.maxX - 76
    }

    private func canMoveAccount(at indexPath: IndexPath) -> Bool {
        guard isEditingAccounts else { return false }
        guard accountID(at: indexPath) != nil else { return false }
        if Section(rawValue: indexPath.section) == .main, visibleAccounts.count <= 1 {
            return false
        }
        return true
    }

    private func indexPath(for accountID: String, in section: Section) -> IndexPath? {
        let accounts = section == .main ? visibleAccounts : otherAccounts
        guard let item = accounts.firstIndex(where: { $0.id == accountID }) else { return nil }
        return IndexPath(item: item, section: section.index)
    }

    private func lockedMovementPoint(for location: CGPoint) -> CGPoint {
        CGPoint(x: interactiveMovementLockedX ?? collectionView.bounds.midX, y: boundedMovementY(for: location.y))
    }

    private func boundedMovementY(for y: CGFloat) -> CGFloat {
        var allowedFrames: [CGRect] = []
        for section in Section.allCases {
            for item in 0..<collectionView.numberOfItems(inSection: section.index) {
                let indexPath = IndexPath(item: item, section: section.index)
                if let attributes = collectionView.collectionViewLayout.layoutAttributesForItem(at: indexPath) {
                    allowedFrames.append(attributes.frame)
                }
            }
        }
        guard let minimumY = allowedFrames.map(\.minY).min(),
              let maximumY = allowedFrames.map(\.maxY).max() else {
            return y
        }
        return min(max(y, minimumY), maximumY)
    }

    private func isPointInsideMainActionDropZone(_ point: CGPoint) -> Bool {
        guard let attributes = collectionView.collectionViewLayout.layoutAttributesForItem(
            at: mainActionIndexPath
        ) else {
            return false
        }
        return attributes.frame.insetBy(dx: -24, dy: -16).contains(point)
    }

    private func mainActionDropDestination(for sourceSection: Section) -> IndexPath? {
        if otherAccounts.isEmpty {
            guard sourceSection == .main, visibleAccounts.count > 1 else { return nil }
            return IndexPath(item: 0, section: Section.other.index)
        }

        guard sourceSection == .other else { return nil }
        let lastMainItem = max(visibleAccounts.count - 1, 0)
        return IndexPath(item: lastMainItem, section: Section.main.index)
    }

    private func maximumDestinationItem(in section: Section, movingFrom sourceSection: Section) -> Int {
        let currentCount: Int
        switch section {
        case .main:
            currentCount = visibleAccounts.count
        case .other:
            currentCount = otherAccounts.count
        }
        return max(0, currentCount - 1)
    }

    private var mainActionIndexPath: IndexPath {
        IndexPath(item: visibleAccounts.count, section: Section.main.index)
    }

    private func isMainActionIndexPath(_ indexPath: IndexPath) -> Bool {
        indexPath.section == Section.main.index && indexPath.item == visibleAccounts.count
    }

    private var visibleAccounts: [Home8FocusAccount] {
        let accounts = visibleAccountIDs.compactMap { id in
            allAccounts.first { $0.id == id }
        }
        return accounts.isEmpty ? Array(allAccounts.prefix(1)) : accounts
    }

    private var otherAccounts: [Home8FocusAccount] {
        hiddenAccountIDs.compactMap { id in
            allAccounts.first { $0.id == id }
        }
    }

    private func account(at indexPath: IndexPath) -> Home8FocusAccount? {
        switch Section(rawValue: indexPath.section) {
        case .main:
            let accounts = visibleAccounts
            guard accounts.indices.contains(indexPath.item) else { return nil }
            return accounts[indexPath.item]
        case .other:
            let accounts = otherAccounts
            guard accounts.indices.contains(indexPath.item) else { return nil }
            return accounts[indexPath.item]
        case nil:
            return nil
        }
    }

    private func accountID(at indexPath: IndexPath) -> String? {
        switch Section(rawValue: indexPath.section) {
        case .main:
            let accounts = visibleAccounts
            guard accounts.indices.contains(indexPath.item) else { return nil }
            return accounts[indexPath.item].id
        case .other:
            let accounts = otherAccounts
            guard accounts.indices.contains(indexPath.item) else { return nil }
            return accounts[indexPath.item].id
        case nil:
            return nil
        }
    }
}

private final class HomeSettingsHostingReusableView: UICollectionReusableView {
    private var hostingController: UIHostingController<AnyView>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure<Content: View>(@ViewBuilder content: () -> Content) {
        let rootView = AnyView(content())

        if let hostingController {
            hostingController.rootView = rootView
            hostingController.view.setNeedsLayout()
            return
        }

        let hostingController = UIHostingController(rootView: rootView)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        self.hostingController = hostingController
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        hostingController?.rootView = AnyView(EmptyView())
    }
}

private struct HomeSettingsSectionHeader: View {
    let title: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.58) : Color(hex: "9299A2"))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }
}

private struct HomeSettingsReorderClueCard: View {
    let isRestoreHint: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: isRestoreHint ? "arrow.up.arrow.down" : "eye")
                .font(.system(size: 14, weight: .semibold))

            Text(
                isRestoreHint
                    ? "Переносите счета, которые хотите\nвидеть на главной"
                    : "Переносите счета, которые хотите\nскрыть с главной"
            )
                .font(.system(size: 13, weight: .regular))
                .kerning(-0.08)
                .multilineTextAlignment(.center)
        }
        .foregroundColor(secondaryTextColor)
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    secondaryTextColor.opacity(0.28),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
        }
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.58) : Color(hex: "9299A2")
    }
}

private struct HomeSettingsEmptyAccountsDropCard: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 16, weight: .semibold))

            Text("Перетащите счет сюда")
                .font(.system(size: 15, weight: .regular))
                .kerning(-0.24)
        }
        .foregroundColor(secondaryTextColor)
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    secondaryTextColor.opacity(0.28),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.58) : Color(hex: "9299A2")
    }
}

private final class HomeAccountEditingState: ObservableObject {
    @Published var isEditing: Bool = false
    @Published var decorationsHidden: Bool = false
    @Published var dragHandleVisible: Bool = false
    @Published var areKopecksHidden: Bool = true
}

private struct HomeAccountMorphCard: View {
    let account: Home8FocusAccount
    let appearance: HomeAccountCompactAppearance?
    @ObservedObject var state: HomeAccountEditingState
    @Environment(\.colorScheme) private var colorScheme

    private static let layoutAnimation = Animation.spring(response: 0.28, dampingFraction: 0.84)
    private static let fadeAnimation = Animation.easeInOut(duration: 0.10)

    private var isEditing: Bool { state.isEditing }
    private var areKopecksHidden: Bool { state.areKopecksHidden }
    private var decorationsHidden: Bool { state.decorationsHidden }
    private var dragHandleVisible: Bool { state.dragHandleVisible }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            accountAvatar
                .padding(.top, 4)
                .padding(.trailing, 16)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    Text(account.balance(kopecksHidden: isEditing ? areKopecksHidden : true))
                        .font(.system(size: 17, weight: .bold))
                        .kerning(-0.41)
                        .foregroundColor(primaryTextColor)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if let badgeText = account.badgeText {
                        accountBadge(text: badgeText, style: account.cardStyle)
                            .opacity(decorationsHidden ? 0 : 1)
                            .animation(Self.fadeAnimation, value: decorationsHidden)
                    }
                }

                Text(account.title)
                    .font(.system(size: 15, weight: .regular))
                    .kerning(-0.24)
                    .foregroundColor(primaryTextColor)
                    .lineLimit(1)

                if !account.cardNumbers.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(account.cardNumbers.indices, id: \.self) { cardIndex in
                            accountCardThumbnail(
                                number: account.cardNumbers[cardIndex],
                                index: cardIndex
                            )
                        }
                    }
                    .padding(.top, 12)
                    .opacity(decorationsHidden ? 0 : 1)
                    .animation(Self.fadeAnimation, value: decorationsHidden)
                    .frame(height: isEditing ? 0 : nil, alignment: .top)
                    .clipped()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(tertiaryTextColor)
                .opacity(dragHandleVisible ? 1 : 0)
                .animation(Self.fadeAnimation, value: dragHandleVisible)
                .frame(width: isEditing ? 40 : 0, height: isEditing ? 50 : 0)
                .clipped()
                .accessibilityLabel("Перетащить \(account.title)")
                .accessibilityHidden(!isEditing)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, isEditing ? 12 : 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: isEditing ? 24 : 28, style: .continuous))
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0 : (isEditing ? 0.06 : 0.05)),
            radius: isEditing ? 24 : 20,
            x: 0,
            y: isEditing ? 6 : 5
        )
        .animation(Self.layoutAnimation, value: isEditing)
    }

    @ViewBuilder
    private var accountAvatar: some View {
        let effectiveAppearance = appearance ?? .default(for: account)
        let isDefaultAvatarSurface = effectiveAppearance.backgroundHex == nil
        let avatarSurfaceColor = effectiveAppearance.backgroundHex.map { Color(hex: $0) } ?? defaultAvatarSurfaceColor

        if let systemIconName = effectiveAppearance.systemIconName {
            Image(systemName: systemIconName)
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(effectiveAppearance.backgroundHex.map { Color(hex: $0) } ?? Color(hex: "428BF9"))
                .frame(width: 40, height: 40)
        } else {
            Circle()
                .fill(avatarSurfaceColor)
                .frame(width: 40, height: 40)
                .overlay {
                    Text(effectiveAppearance.emoji)
                        .font(.system(size: account.cardStyle == .platinum ? 20 : 24, weight: .bold, design: .rounded))
                        .foregroundColor(effectiveAppearance.backgroundHex == nil ? defaultAvatarTextColor : .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: 32, height: 32, alignment: .center)
                }
                .overlay {
                    if isDefaultAvatarSurface && colorScheme != .dark {
                        Circle()
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    }
                }
                .shadow(
                    color: Color.black.opacity(isDefaultAvatarSurface && colorScheme != .dark ? 0.08 : 0),
                    radius: 10,
                    x: 0,
                    y: 4
                )
        }
    }

    private var defaultAvatarSurfaceColor: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : .white
    }

    private var defaultAvatarTextColor: Color {
        colorScheme == .dark ? .white : Color(hex: "333333")
    }

    private func accountBadge(text: String, style: Home8FocusCardStyle) -> some View {
        HStack(spacing: 3) {
            Image(systemName: style == .black ? "crown.fill" : "sparkle")
                .font(.system(size: 8, weight: .bold))
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .kerning(-0.1)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .frame(height: 18)
        .background(
            Capsule(style: .continuous)
                .fill(style == .black ? Color(hex: "333333") : Color(hex: "747B8F"))
        )
    }

    private func accountCardThumbnail(number: String, index: Int) -> some View {
        ZStack(alignment: .bottomLeading) {
            switch account.cardStyle {
            case .black:
                Image("card")
                    .resizable()
                    .scaledToFill()
                    .saturation(index == 0 ? 1 : 0)
                    .brightness(index == 0 ? 0 : 0.08)
            case .platinum:
                Image("card")
                    .resizable()
                    .scaledToFill()
                    .saturation(0)
                    .brightness(0.18)
            case .savings, .joint, .wallet:
                LinearGradient(
                    colors: [Color(hex: "7CAEFF"), Color(hex: "4972CF")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            Text(number)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .padding(.leading, 4)
                .padding(.bottom, 3)
        }
        .frame(width: 48, height: 32)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : .white
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color(hex: "333333")
    }

    private var tertiaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.30) : Color(hex: "001024").opacity(0.22)
    }
}

private struct SnowSettingsSheet: View {
    @Binding var snowSettings: SnowEffectSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                section("Эффект refresh") {
                    Toggle("Показывать после refresh", isOn: $snowSettings.isEnabled)

                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Тип эффекта")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)

                            Picker("Тип эффекта", selection: $snowSettings.effectKind) {
                                Text("Снег").tag(PullRefreshEffectKind.snow)
                                Text("Листья").tag(PullRefreshEffectKind.leaves)
                                Text("Эмоджи").tag(PullRefreshEffectKind.emoji)
                            }
                            .pickerStyle(.segmented)
                        }

                        if snowSettings.effectKind == .emoji {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Emoji")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)

                                TextField(
                                    "🍂❄️✨",
                                    text: $snowSettings.emojiSymbol
                                )
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 24))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            }
                        }

                        slider(
                            title: "Длительность эмиссии",
                            value: $snowSettings.emissionDuration,
                            range: 1.0...3.5,
                            valueText: String(format: "%.1f с", snowSettings.emissionDuration)
                        )

                        slider(
                            title: "Высота зоны",
                            value: $snowSettings.overlayHeightPercent,
                            range: 0...100,
                            valueText: "\(Int(snowSettings.overlayHeightPercent.rounded()))%"
                        )

                        slider(
                            title: "Плотность",
                            value: $snowSettings.densityMultiplier,
                            range: 0.25...2.5,
                            valueText: "\(Int((snowSettings.densityMultiplier * 100).rounded()))%"
                        )

                        slider(
                            title: "Скорость падения",
                            value: $snowSettings.speedMultiplier,
                            range: 0.45...1.9,
                            valueText: "\(Int((snowSettings.speedMultiplier * 100).rounded()))%"
                        )

                        slider(
                            title: "Размер частиц",
                            value: $snowSettings.scaleMultiplier,
                            range: 0.55...1.8,
                            valueText: "\(Int((snowSettings.scaleMultiplier * 100).rounded()))%"
                        )

                        slider(
                            title: "Размытие",
                            value: $snowSettings.blurMultiplier,
                            range: 0...2,
                            valueText: "\(Int((snowSettings.blurMultiplier * 100).rounded()))%"
                        )

                        slider(
                            title: "Прозрачность",
                            value: $snowSettings.alphaMultiplier,
                            range: 0.35...2.5,
                            valueText: "\(Int((snowSettings.alphaMultiplier * 100).rounded()))%"
                        )

                        slider(
                            title: "Турбулентность",
                            value: $snowSettings.turbulenceMultiplier,
                            range: 0...1.8,
                            valueText: "\(Int((snowSettings.turbulenceMultiplier * 100).rounded()))%"
                        )
                    }
                    .opacity(snowSettings.isEnabled ? 1 : 0.4)
                    .disabled(!snowSettings.isEnabled)

                    Button {
                        snowSettings.resetCurrentPreset()
                    } label: {
                        Label("Сбросить настройки пресета", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .tracking(-0.41)

            content()
        }
    }

    private func slider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        valueText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .regular))
                Spacer()
                Text(valueText)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack { TestInAppView() }
}
