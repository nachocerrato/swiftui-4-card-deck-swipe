//
//  CardDeckPickerView.swift
//  Palabros
//
//  Created by Nacho Cerrato on 7/3/26.
//

import SwiftUI
import UIKit

struct CardDeckPickerView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedIndex: Int
    @State private var isApplying = false
    @State private var ringPulse = false
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var displayedIndex: Int

    // Exit animation state
    @State private var isExiting = false
    @State private var exitDirection: Int = 0   // -1 = left, +1 = right
    @State private var pendingIndex: Int = 0    // index to apply after exit
    @State private var exitSequence = 0
    @State private var skipsAnimatedDisplayedIndexSync = false
    @State private var suppressesDeckSelectionAnimation = false
    @State private var keepsIncomingOverlayDuringSnapBack = false

    @State private var incomingSwipeCardIndex: Int?
    @State private var incomingXOffset: CGFloat = 22
    @State private var incomingYOffset: CGFloat = 22
    @State private var incomingRotation: Double = 12.0
    @State private var incomingScale: CGFloat = 0.91
    @State private var incomingOpacity: Double = 0
    @State private var incomingZIndex: Double = 10
    @State private var incomingIsFront = false
    @State private var incomingShadowRadius: CGFloat = 0
    @State private var incomingShadowY: CGFloat = 0

    @State private var outgoingXOffset: CGFloat = 0
    @State private var outgoingYOffset: CGFloat = 0
    @State private var outgoingRotation: Double = 0
    @State private var outgoingScale: CGFloat = 1
    @State private var outgoingOpacity: Double = 0
    @State private var outgoingZIndex: Double = 100
    @State private var outgoingIsFront = true
    @State private var outgoingShadowRadius: CGFloat = 24
    @State private var outgoingShadowY: CGFloat = 12

    private let icons = DemoCard.allCases

    private let cardSize: CGFloat = 176
    private let swipeThreshold: CGFloat = 90
    private let haptics = UIImpactFeedbackGenerator(style: .medium)

    // Timing constants
    private let exitDurationLeft: Double = 0.42
    private let exitDurationRight: Double = 0.54   // más largo: la previous tiene más viaje
    private let exitResponse: Double = 0.45
    private let exitDamping: Double = 0.88
    private let rightExitPhaseOneDelay: Double = 0.24

    var showsHandle = false
    var onSelectionChanged: ((DemoCard) -> Void)?

    init(showsHandle: Bool = false, onSelectionChanged: ((DemoCard) -> Void)? = nil) {
        self.showsHandle = showsHandle
        self.onSelectionChanged = onSelectionChanged
        let current = DemoCard.current()
        let idx = DemoCard.allCases.firstIndex(of: current) ?? 0
        _selectedIndex = State(initialValue: idx)
        _displayedIndex = State(initialValue: idx)
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            backgroundGradient
                .overlay { backgroundGlow }
                .animation(.spring(response: 0.6, dampingFraction: 0.86), value: displayedIndex)

            VStack(spacing: 0) {
                if showsHandle {
                    dragPill
                        .padding(.top, 8)
                }

                deckView
                    .padding(.top, showsHandle ? 26 : 30)

                activeLabel
                    .padding(.top, 22)

                pageIndicators
                    .padding(.top, 14)
                    .padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipShape(.rect(cornerRadius: 30))
        .accessibilityIdentifier("appearance.iconPicker")
        .onAppear {
            haptics.prepare()
            withAnimation(
                .easeInOut(duration: 1.1)
                .repeatForever(autoreverses: true)
            ) {
                ringPulse = true
            }
        }
        .onChange(of: selectedIndex) { _, newIndex in
            if skipsAnimatedDisplayedIndexSync {
                skipsAnimatedDisplayedIndexSync = false
                return
            }

            withAnimation(.spring(response: 0.56, dampingFraction: 0.84)) {
                displayedIndex = newIndex
            }
        }
    }

    // MARK: - Deck

    private var deckView: some View {
        ZStack {
            ForEach(Array(icons.enumerated()), id: \.offset) { idx, icon in
                deckCard(icon: icon, index: idx)
            }

            if let index = incomingSwipeOverlayIndex,
               let icon = icons[safe: index] {
                premiumCard(icon: icon, cardState: incomingOverlayCardState)
            }

            frontRingOverlay
        }
        .frame(width: cardSize + 60, height: cardSize + 50)
        .contentShape(Rectangle())
        .gesture(deckDragGesture)
    }

    @ViewBuilder
    private func deckCard(icon: DemoCard, index: Int) -> some View {
        let cardState = state(for: index)
        premiumCard(icon: icon, cardState: cardState)
    }

    private func premiumCard(icon: DemoCard, cardState: DeckCardState) -> some View {
        let cornerRadius = cardSize * 0.2225
        let uiImage = UIImage(named: icon.previewImageName) ?? UIImage()

        return ZStack {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: cardSize, height: cardSize)
                .clipShape(.rect(cornerRadius: cornerRadius))
                .overlay {
                    if isDarkIcon(icon) && cardState.isFront {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(darkCardEdgeColor, lineWidth: 1)
                    }
                }
                .overlay {
                    // Sheen inside clipShape — avoids bleed-through artifact
                    if cardState.isFront {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(cardSheen(for: icon))
                    }
                }
        }
        .shadow(
            color: shadowColor(for: icon).opacity(cardState.isFront ? 1 : 0.5),
            radius: cardState.shadowRadius,
            x: 0,
            y: cardState.shadowY
        )
        .scaleEffect(cardState.scale)
        .rotationEffect(.degrees(cardState.rotation))
        .offset(x: cardState.xOffset, y: cardState.yOffset)
        .opacity(cardState.opacity)
        .zIndex(cardState.zIndex)
        .animation(.spring(response: exitResponse, dampingFraction: exitDamping), value: isExiting)
        .animation(
            suppressesDeckSelectionAnimation ? nil : .spring(response: 0.52, dampingFraction: 0.82),
            value: selectedIndex
        )
        .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.72), value: dragOffset)
    }

    @ViewBuilder
    private var frontRingOverlay: some View {
        if let ring = activeFrontRing {
            let cornerRadius = cardSize * 0.2225

            RoundedRectangle(cornerRadius: cornerRadius + 6, style: .continuous)
                .strokeBorder(ringColor(for: ring.icon).opacity(0.34), lineWidth: 2.2)
                .frame(width: cardSize + 10, height: cardSize + 10)
                .blur(radius: ringPulse ? 8 : 6)
                .opacity(ringPulse ? 0.95 : 0.78)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius + 7, style: .continuous)
                        .strokeBorder(ringColor(for: ring.icon).opacity(0.18), lineWidth: 4)
                        .blur(radius: ringPulse ? 16 : 13)
                        .opacity(ringPulse ? 0.72 : 0.52)
                }
                .scaleEffect(ring.state.scale)
                .rotationEffect(.degrees(ring.state.rotation))
                .offset(x: ring.state.xOffset, y: ring.state.yOffset)
                .zIndex(200)
                .allowsHitTesting(false)
                .animation(
                    .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                    value: ringPulse
                )
                .animation(.spring(response: exitResponse, dampingFraction: exitDamping), value: isExiting)
                .animation(
                    suppressesDeckSelectionAnimation ? nil : .spring(response: 0.52, dampingFraction: 0.82),
                    value: selectedIndex
                )
                .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.72), value: dragOffset)
        }
    }

    private var activeFrontRing: (icon: DemoCard, state: DeckCardState)? {
        if let index = incomingSwipeCardIndex,
           incomingIsFront,
           let icon = icons[safe: index] {
            return (icon, incomingOverlayCardState)
        }

        guard let icon = icons[safe: selectedIndex] else {
            return nil
        }

        return (icon, state(for: selectedIndex))
    }

    // MARK: - Active Label

    private var activeLabel: some View {
        let icon = icons[safe: displayedIndex] ?? .card1

        return HStack(spacing: 8) {
            Text(icon.displayName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(nameColor(for: icon))

        }
        .accessibilityIdentifier("appearance.iconPicker.activeLabel")
        .contentTransition(.interpolate)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: displayedIndex)
    }

    // MARK: - Drag Pill

    private var dragPill: some View {
        Capsule()
            .fill(pillColor)
            .frame(width: 36, height: 5)
    }

    // MARK: - Page Indicators

    private var pageIndicators: some View {
        HStack(spacing: 7) {
            ForEach(0..<icons.count, id: \.self) { idx in
                Capsule()
                    .frame(width: idx == selectedIndex ? 20 : 7, height: 7)
                    .foregroundStyle(
                        idx == selectedIndex ? indicatorActiveColor : indicatorInactiveColor
                    )
                    .animation(.spring(response: 0.32, dampingFraction: 0.80), value: selectedIndex)
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        let colors = backgroundColors(for: icons[safe: displayedIndex] ?? .card1)
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var backgroundGlow: some View {
        let icon = icons[safe: displayedIndex] ?? .card1

        return Circle()
            .fill(glowColor(for: icon).opacity(isDarkIcon(icon) ? 0.40 : 0.28))
            .frame(width: 260, height: 260)
            .blur(radius: 50)
            .offset(x: dragOffset * 0.12, y: 60)
            .allowsHitTesting(false)
    }

    // MARK: - Gesture

    private var deckDragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                if isExiting {
                    return
                }

                isDragging = true
                dragOffset = value.translation.width

                if value.translation.width > 0 {
                    keepsIncomingOverlayDuringSnapBack = true
                }
            }
            .onEnded { value in
                isDragging = false

                let translation = value.translation.width
                let predicted = value.predictedEndTranslation.width
                let finalTranslation = abs(predicted) > abs(translation) ? predicted : translation

                // Izquierda usa el predictor (flick natural funciona bien).
                // Derecha usa solo la distancia real para evitar que un micro-flick
                // dispare el exit antes de que el usuario haya arrastrado de verdad.
                if finalTranslation <= -swipeThreshold {
                    initiateExit(direction: -1, targetIndex: selectedIndex + 1)
                } else if translation >= swipeThreshold {
                    initiateExit(direction: +1, targetIndex: selectedIndex - 1)
                } else {
                    let keepsIncomingOverlay = translation > 0
                    keepsIncomingOverlayDuringSnapBack = keepsIncomingOverlay

                    // Snap back — not enough swipe
                    withAnimation(.spring(response: 0.44, dampingFraction: 0.82)) {
                        dragOffset = 0
                    }

                    if keepsIncomingOverlay {
                        let sequence = exitSequence
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.44) {
                            guard sequence == exitSequence, !isExiting else { return }
                            keepsIncomingOverlayDuringSnapBack = false
                        }
                    } else {
                        keepsIncomingOverlayDuringSnapBack = false
                    }
                }
            }
    }

    // MARK: - Exit Animation

    /// Kicks off the two-phase exit: animate card out, then commit the index change.
    private func initiateExit(direction: Int, targetIndex: Int) {
        let count = icons.count
        let wrapped = ((targetIndex % count) + count) % count

        guard wrapped != selectedIndex else {
            withAnimation(.spring(response: 0.44, dampingFraction: 0.82)) {
                dragOffset = 0
            }
            return
        }

        triggerHaptic()
        pendingIndex = wrapped
        exitSequence += 1
        keepsIncomingOverlayDuringSnapBack = false
        let sequence = exitSequence

        if direction == -1 {
            startLeftExit(sequence: sequence)
        } else {
            startRightExit(sequence: sequence)
        }
    }

    private func startLeftExit(sequence: Int) {
        exitDirection = -1

        withAnimation(.spring(response: exitResponse, dampingFraction: exitDamping)) {
            isExiting = true
            dragOffset = -250
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + exitDurationLeft) {
            guard sequence == exitSequence else { return }

            self.selectedIndex = self.pendingIndex
            self.isExiting = false
            self.exitDirection = 0
            withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
                self.dragOffset = 0
            }
            self.applyIcon(at: self.pendingIndex)
        }
    }
    private func startRightExit(sequence: Int) {
        let incomingStartState = interactiveIncomingCardState(for: dragOffset)
        let outgoingStartState = interactiveFrontCardState(for: dragOffset)
        incomingSwipeCardIndex = wrappedIndex(selectedIndex - 1)
        applyIncomingOverlayState(incomingStartState)
        applyOutgoingOverlayState(outgoingStartState)
        exitDirection = 1
        isExiting = true

        // ─── Phase A: lateral escape ──────────────────────────────────────
        // Continue the incoming card's trajectory from interactiveIncomingCardState,
        // pushing it further left/below stack edge WITHOUT a z-index spike.
        // This preserves occlusion — the card never visually "passes through" the
        // cards still in front of it.
        withAnimation(.spring(response: 0.38, dampingFraction: 0.76)) {
            dragOffset = 160

            incomingXOffset = -170    // wide enough that the bottom-right corner fully clears
            incomingYOffset = 26
            incomingRotation = -26    // folds around the corner — deeper bend
            incomingScale = 0.86      // shrinks in perspective during the escape
            incomingOpacity = 1
            incomingZIndex = 14       // stays behind the front/back cards
            incomingIsFront = false
            incomingShadowRadius = 10
            incomingShadowY = 5

            outgoingXOffset = 72
            outgoingYOffset = 6
            outgoingRotation = 6
            outgoingScale = 0.965
            outgoingOpacity = 1
            outgoingZIndex = 92
            outgoingIsFront = false
            outgoingShadowRadius = 10
            outgoingShadowY = 5
        }

        // ─── Phase B: coronation ──────────────────────────────────────────
        // The incoming card has now cleared the stack edge visually.
        // Only NOW do we raise its z-index and arc it inward to crown as the new front.
        DispatchQueue.main.asyncAfter(deadline: .now() + rightExitPhaseOneDelay) {
            guard sequence == exitSequence else { return }

            withAnimation(.spring(response: 0.56, dampingFraction: 0.84)) {
                displayedIndex = pendingIndex
            }

            withAnimation(.spring(response: 0.32, dampingFraction: 0.74)) {
                incomingXOffset = 0
                incomingYOffset = 0
                incomingRotation = 0
                incomingScale = 1.0
                incomingOpacity = 1
                incomingZIndex = 106  // now legitimately in front — card has cleared the stack
                incomingIsFront = true
                incomingShadowRadius = 24
                incomingShadowY = 12

                outgoingXOffset = 8
                outgoingYOffset = 8
                outgoingRotation = 4
                outgoingScale = 0.97
                outgoingOpacity = 1
                outgoingZIndex = 31   // fix: avoids z-index collision with Back 2
                outgoingIsFront = false
                outgoingShadowRadius = 0
                outgoingShadowY = 0
            }
        }

        // ─── Cleanup ──────────────────────────────────────────────────────
        DispatchQueue.main.asyncAfter(deadline: .now() + exitDurationRight) {
            guard sequence == exitSequence else { return }

            suppressesDeckSelectionAnimation = true

            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                skipsAnimatedDisplayedIndexSync = true
                selectedIndex = pendingIndex
                displayedIndex = pendingIndex
                isExiting = false
                exitDirection = 0
                dragOffset = 0
                incomingSwipeCardIndex = nil
                resetIncomingOverlayToBack()
                resetOutgoingOverlayToFront()
            }

            DispatchQueue.main.async {
                guard sequence == exitSequence else { return }
                suppressesDeckSelectionAnimation = false
            }

            applyIcon(at: pendingIndex)
        }
    }


    private func applyIcon(at index: Int) {
        let icon = icons[safe: index] ?? .card1
        guard !isApplying else { return }
        isApplying = true
        
        // Save the choice locally but do NOT trigger the system change yet
        // to avoid the iOS UIAlertController interrupting the deck animation.
        icon.save()
        onSelectionChanged?(icon)
        
        // Brief debounce to prevent rapid spamming
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isApplying = false
        }
    }

    private func triggerHaptic() {
        haptics.impactOccurred(intensity: 0.75)
        haptics.prepare()
    }

    private var incomingSwipeOverlayIndex: Int? {
        if let incomingSwipeCardIndex {
            return incomingSwipeCardIndex
        }

        guard dragOffset > 0 else {
            return keepsIncomingOverlayDuringSnapBack ? wrappedIndex(selectedIndex - 1) : nil
        }

        return wrappedIndex(selectedIndex - 1)
    }

    private var incomingOverlayCardState: DeckCardState {
        if incomingSwipeCardIndex != nil {
            return DeckCardState(
                scale: incomingScale,
                xOffset: incomingXOffset,
                yOffset: incomingYOffset,
                rotation: incomingRotation,
                opacity: incomingOpacity,
                zIndex: incomingZIndex,
                isFront: incomingIsFront,
                shadowRadius: incomingShadowRadius,
                shadowY: incomingShadowY
            )
        }

        return interactiveIncomingCardState(for: dragOffset)
    }

    private var outgoingOverlayCardState: DeckCardState {
        DeckCardState(
            scale: outgoingScale,
            xOffset: outgoingXOffset,
            yOffset: outgoingYOffset,
            rotation: outgoingRotation,
            opacity: outgoingOpacity,
            zIndex: outgoingZIndex,
            isFront: outgoingIsFront,
            shadowRadius: outgoingShadowRadius,
            shadowY: outgoingShadowY
        )
    }

    private func interactiveIncomingCardState(for offset: CGFloat) -> DeckCardState {
        let progress = max(0, min(1, offset / 150.0))
        let eased = 1 - pow(1 - progress, 2)

        return DeckCardState(
            scale: 0.91 + (0.06 * eased),
            xOffset: 22 - (68 * eased),
            yOffset: 22 - (18 * eased),
            rotation: 12.0 - (18.0 * eased),
            opacity: 1,
            zIndex: 12,
            isFront: false,
            shadowRadius: 5 + (10 * eased),
            shadowY: 2 + (4 * eased)
        )
    }

    private func interactiveFrontCardState(for offset: CGFloat) -> DeckCardState {
        let dragProgress = max(-1.0, min(1.0, offset / 140.0))
        let leftProgress = max(0, -dragProgress)
        let rightProgress = max(0, dragProgress)

        return DeckCardState(
            scale: 1.0 - 0.03 * leftProgress - 0.015 * rightProgress,
            xOffset: (offset * 0.42 * (1 - rightProgress * 0.55)) + (10 * rightProgress),
            yOffset: 6 * leftProgress + 4 * rightProgress,
            rotation: -9.0 * leftProgress + 4.0 * rightProgress,
            opacity: 1,
            zIndex: 100,
            isFront: true,
            shadowRadius: 24,
            shadowY: 12
        )
    }

    private func applyIncomingOverlayState(_ state: DeckCardState) {
        incomingScale = state.scale
        incomingXOffset = state.xOffset
        incomingYOffset = state.yOffset
        incomingRotation = state.rotation
        incomingOpacity = state.opacity
        incomingZIndex = state.zIndex
        incomingIsFront = state.isFront
        incomingShadowRadius = state.shadowRadius
        incomingShadowY = state.shadowY
    }

    private func applyOutgoingOverlayState(_ state: DeckCardState) {
        outgoingScale = state.scale
        outgoingXOffset = state.xOffset
        outgoingYOffset = state.yOffset
        outgoingRotation = state.rotation
        outgoingOpacity = state.opacity
        outgoingZIndex = state.zIndex
        outgoingIsFront = state.isFront
        outgoingShadowRadius = state.shadowRadius
        outgoingShadowY = state.shadowY
    }

    private func resetIncomingOverlayToBack() {
        incomingScale = 0.91
        incomingXOffset = 22
        incomingYOffset = 22
        incomingRotation = 12.0
        incomingOpacity = 0
        incomingZIndex = 10
        incomingIsFront = false
        incomingShadowRadius = 0
        incomingShadowY = 0
    }

    private func resetOutgoingOverlayToFront() {
        outgoingScale = 1
        outgoingXOffset = 0
        outgoingYOffset = 0
        outgoingRotation = 0
        outgoingOpacity = 0
        outgoingZIndex = 100
        outgoingIsFront = true
        outgoingShadowRadius = 24
        outgoingShadowY = 12
    }

    private func wrappedIndex(_ index: Int) -> Int {
        let count = icons.count
        return ((index % count) + count) % count
    }

    // MARK: - Deck State

    /// Returns the visual state for the card at `index` given the current `selectedIndex`,
    /// `dragOffset`, `isExiting`, and `exitDirection`.
    ///
    /// Layout (at rest):
    ///   forward=0  → front card: full size, centered
    ///   forward=1  → back1: slightly smaller, shifted 8px down-right, rotated 4°
    ///   forward=2  → back2: smaller, 15px down-right, 8°
    ///   forward=3  → back3: smallest, 22px down-right, 12°
    ///
    /// During drag/exit:
    ///   leftProgress  → front flies left/tilts; backs slide toward front
    ///   rightProgress → previousIndex card emerges from bottom-right toward front
    private func state(for index: Int) -> DeckCardState {
        let count = icons.count
        let forward = (index - selectedIndex + count) % count
        let previousIndex = wrappedIndex(selectedIndex - 1)
        
        // For right exit, we must keep hiding the underlying incoming card 
        // until the ENTIRE exit duration has finished and index has snapped.
        let isIncomingCard = index == previousIndex || (isExiting && exitDirection == 1 && index == incomingSwipeCardIndex)
        
        let shouldHideIncomingForOverlay = isIncomingCard
            && (incomingSwipeOverlayIndex == previousIndex || (isExiting && exitDirection == 1))
            && index != selectedIndex

        // Unified drag progress used for interactive drag AND exit animation
        let dragProgress = max(-1.0, min(1.0, dragOffset / 140.0))
        let leftProgress = max(0, -dragProgress)
        let rightProgress = max(0, dragProgress)
        // Ensure stack progress maxes out gracefully during a right exit
        let rightStackProgress = isExiting && exitDirection == 1 ? (min(1.0, rightProgress + 0.15)) : rightProgress

        if shouldHideIncomingForOverlay {
            return DeckCardState(
                scale: 0.91,
                xOffset: 22,
                yOffset: 22,
                rotation: 12.0,
                opacity: 0,
                zIndex: 0,
                isFront: false,
                shadowRadius: 0,
                shadowY: 0
            )
        }

        switch forward {

        // ─── FRONT CARD ───────────────────────────────────────────────
        case 0:
            if isExiting && exitDirection == 1 {
                return outgoingOverlayCardState
            }

            // During a left exit the card slides fully off-screen to the left
            // During a right exit it slides off to the right
            // During interactive drag it follows the finger (capped)
            let xOff: CGFloat
            let rot: Double
            let sc: CGFloat
            let yOff: CGFloat

            if isExiting && exitDirection == -1 {
                // Left exit: card flies smoothly off to the left
                xOff = dragOffset * 0.90        // dragOffset is −320 → ~−288
                rot  = -18.0
                sc   = 0.92
                yOff = 10
            } else {
                // Interactive drag — front card follows finger symmetrically
                // leftProgress drives it left, rightProgress drives it right
                xOff = (dragOffset * 0.42 * (1 - rightProgress * 0.55)) + (10 * rightProgress)
                rot  = -9.0 * leftProgress + 4.0 * rightProgress
                sc   = 1.0 - 0.03 * leftProgress - 0.015 * rightProgress
                yOff = 6 * leftProgress + 4 * rightProgress
            }

            return DeckCardState(
                scale: sc,
                xOffset: xOff,
                yOffset: yOff,
                rotation: rot,
                opacity: 1,
                zIndex: 100,
                isFront: true,
                shadowRadius: 24,
                shadowY: 12
            )

        // ─── BACK 1 ───────────────────────────────────────────────────
        case 1:
            return DeckCardState(
                scale: 0.97 + (0.03 * leftProgress) - (0.03 * rightStackProgress),
                xOffset: 8 - (8 * leftProgress) + (7 * rightStackProgress),
                yOffset: 8 - (8 * leftProgress) + (7 * rightStackProgress),
                rotation: 4.0 - (4.0 * leftProgress) + (4.0 * rightStackProgress),
                opacity: 1,
                zIndex: 30,
                isFront: false,
                shadowRadius: 0,
                shadowY: 0
            )

        // ─── BACK 2 ───────────────────────────────────────────────────
        case 2:
            return DeckCardState(
                scale: 0.94 + (0.03 * leftProgress) - (0.03 * rightStackProgress),
                xOffset: 15 - (8 * leftProgress) + (7 * rightStackProgress),
                yOffset: 15 - (8 * leftProgress) + (7 * rightStackProgress),
                rotation: 8.0 - (4.0 * leftProgress) + (4.0 * rightStackProgress),
                opacity: 1 - (0.06 * rightStackProgress),
                zIndex: 20,
                isFront: false,
                shadowRadius: 0,
                shadowY: 0
            )

        // ─── BACK 3 ───────────────────────────────────────────────────
        case 3:
            return DeckCardState(
                scale: 0.91 + (0.03 * leftProgress) - (0.025 * rightStackProgress),
                xOffset: 22 - (8 * leftProgress) + (7 * rightStackProgress),
                yOffset: 22 - (8 * leftProgress) + (7 * rightStackProgress),
                rotation: 12.0 - (4.0 * leftProgress) + (4.0 * rightStackProgress),
                opacity: 1 - (0.18 * rightStackProgress),
                zIndex: 10,
                isFront: false,
                shadowRadius: 0,
                shadowY: 0
            )

        // ─── Hidden ───────────────────────────────────────────────────
        default:
            return DeckCardState(
                scale: 0.91,
                xOffset: 22,
                yOffset: 22,
                rotation: 12.0,
                opacity: 0,
                zIndex: 0,
                isFront: false,
                shadowRadius: 0,
                shadowY: 0
            )
        }
    }

    // MARK: - Color Helpers

    private func isDarkIcon(_ icon: DemoCard) -> Bool {
        icon == .card2 || icon == .card4
    }

    private func backgroundColors(for icon: DemoCard) -> [Color] {
        switch icon {
        case .card1:
            return colorScheme == .dark
                ? [Color(white: 0.11), Color(white: 0.17)]
                : [Color(white: 0.93), Color(white: 0.98)]
        case .card2:
            return [Color(white: 0.13), Color(white: 0.20)]
        case .card3:
            return colorScheme == .dark
                ? [Color(red: 0.05, green: 0.18, blue: 0.32), Color(red: 0.06, green: 0.28, blue: 0.22)]
                : [Color(red: 0.82, green: 0.93, blue: 1.0), Color(red: 0.88, green: 1.0, blue: 0.92)]
        case .card4:
            return [Color(red: 0.06, green: 0.12, blue: 0.24), Color(red: 0.05, green: 0.20, blue: 0.16)]
        }
    }

    private func shadowColor(for icon: DemoCard) -> Color {
        switch icon {
        case .card1:    return .black.opacity(0.16)
        case .card2:     return .black.opacity(0.30)
        case .card3: return Color(red: 0.17, green: 0.55, blue: 0.96).opacity(0.28)
        case .card4:  return Color(red: 0.17, green: 0.55, blue: 0.96).opacity(0.42)
        }
    }

    private var darkCardEdgeColor: Color {
        .white.opacity(0.14)
    }

    private func glowColor(for icon: DemoCard) -> Color {
        switch icon {
        case .card1:    return .white
        case .card2:     return .white.opacity(0.55)
        case .card3: return Color(red: 0.28, green: 0.72, blue: 0.98)
        case .card4:  return Color(red: 0.08, green: 0.62, blue: 0.88)
        }
    }

    private func cardSheen(for icon: DemoCard) -> some ShapeStyle {
        LinearGradient(
            colors: [
                .white.opacity(isDarkIcon(icon) ? 0.10 : 0.22),
                .clear,
                glowColor(for: icon).opacity(isDarkIcon(icon) ? 0.06 : 0.12),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func nameColor(for icon: DemoCard) -> Color {
        switch icon {
        case .card2, .card4:
            return .white
        case .card3:
            return colorScheme == .dark ? .white : Color(red: 0.10, green: 0.35, blue: 0.65)
        case .card1:
            return colorScheme == .dark ? .white : Color(white: 0.12)
        }
    }

    private func ringColor(for icon: DemoCard) -> Color {
        switch icon {
        case .card3, .card4:
            return Color(red: 0.17, green: 0.55, blue: 0.96)
        case .card2:
            return .white.opacity(0.70)
        case .card1:
            return colorScheme == .dark
                ? .white.opacity(0.60)
                : Color(white: 0.40)
        }
    }

    private var indicatorActiveColor: Color {
        let icon = icons[safe: displayedIndex] ?? .card1
        switch icon {
        case .card3, .card4:
            return Color(red: 0.17, green: 0.55, blue: 0.96)
        case .card2:
            return .white
        case .card1:
            return colorScheme == .dark ? .white : Color(white: 0.20)
        }
    }

    private var indicatorInactiveColor: Color {
        let icon = icons[safe: displayedIndex] ?? .card1
        return isDarkIcon(icon)
            ? .white.opacity(0.28)
            : colorScheme == .dark
                ? .white.opacity(0.28)
                : .black.opacity(0.18)
    }

    private var pillColor: Color {
        let icon = icons[safe: displayedIndex] ?? .card1
        return isDarkIcon(icon)
            ? .white.opacity(0.35)
            : colorScheme == .dark
                ? .white.opacity(0.35)
                : .black.opacity(0.22)
    }
}

// MARK: - Deck Card State

private struct DeckCardState {
    let scale: CGFloat
    let xOffset: CGFloat
    let yOffset: CGFloat
    let rotation: Double
    let opacity: Double
    let zIndex: Double
    let isFront: Bool
    let shadowRadius: CGFloat
    let shadowY: CGFloat
}

// MARK: - Safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    CardDeckPickerView()
}
