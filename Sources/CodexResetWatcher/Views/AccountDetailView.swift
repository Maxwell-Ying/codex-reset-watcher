import AppKit
import SwiftUI

struct AccountDetailView: View {
    let detail: AccountDetailState
    let cachedAccountCount: Int
    let onRefresh: () -> Void
    let onForget: (AccountSnapshotID) -> Void
    let onClearStale: () -> Void
    let onClearCached: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CodexStyle.Spacing.section) {
            headerCard

            if detail.isCached {
                snapshotBanner
            }

            ForEach(detail.errorMessages, id: \.self) { message in
                errorBanner(message)
            }

            if detail.usageWindows.isEmpty, detail.credits.isEmpty, detail.isRefreshing {
                loadingState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: CodexStyle.Spacing.stack) {
                        resetSection

                        NudgeCardView(nudge: detail.nudge)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: CodexStyle.Spacing.panel) {
                            ForEach(detail.usageWindows) { window in
                                UsageLimitCardView(window: window)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            footer
        }
        .padding(CodexStyle.Spacing.page)
        .background(CodexPalette.appBackground)
    }

    private var headerCard: some View {
        HStack(spacing: CodexStyle.Spacing.panel) {
            HeaderArtworkView()
                .frame(width: CodexStyle.Size.artworkWidth, height: CodexStyle.Size.artworkHeight)
                .clipShape(RoundedRectangle(cornerRadius: CodexStyle.Radius.artwork, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Label(detail.planLabel, systemImage: "terminal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CodexPalette.mutedText)

                Text("Codex 重置观察器")
                    .font(CodexStyle.Typography.appTitle)

                Text(detail.statusDetail)
                    .font(.subheadline)
                    .foregroundStyle(CodexPalette.secondaryText)
                    .lineLimit(1)

                Text("\(detail.isActive ? "当前" : "账号")：\(detail.accountLabel)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(CodexPalette.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(detail.availableCount)")
                    .font(CodexStyle.Typography.largeMetric)
                    .monospacedDigit()
                Text(resetCountLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CodexPalette.secondaryText)
            }
        }
        .padding(CodexStyle.Spacing.panel)
        .codexPanel()
    }

    private var resetCountLabel: String {
        return detail.isCached ? "上次记录的重置" : "可用重置"
    }

    private var snapshotBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: detail.isStale ? "clock.badge.exclamationmark" : "clock.arrow.circlepath")
                .font(.title3.weight(.semibold))
                .foregroundStyle(detail.isStale ? CodexPalette.warningOrange : CodexPalette.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(detail.statusTitle)
                    .font(CodexStyle.Typography.cardTitle)
                Text(detail.isStale ? "显示的重置窗口已经过去。请登录这个 Codex 账号以刷新。" : "这是本地缓存快照。请登录这个 Codex 账号以刷新。")
                    .font(.subheadline)
                    .foregroundStyle(CodexPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(CodexStyle.Spacing.panel)
        .codexPanel(
            background: detail.isStale ? CodexPalette.warningOrange.opacity(0.10) : CodexPalette.panelBackground,
            border: detail.isStale ? CodexPalette.warningOrange.opacity(0.24) : CodexPalette.selectedBorder,
            shadow: false
        )
    }

    private var resetSection: some View {
        VStack(alignment: .leading, spacing: CodexStyle.Spacing.stack) {
            HStack {
                Text("重置到期")
                    .font(CodexStyle.Typography.sectionTitle)
                Spacer()
                Text("\(detail.availableCount) \(detail.isCached ? "上次记录" : "可用")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CodexPalette.secondaryText)
            }

            if detail.credits.isEmpty, detail.errorMessages.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(detail.credits.enumerated()), id: \.element.id) { index, credit in
                        CreditRowView(credit: credit, ordinal: index + 1)
                    }
                }
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.large)
            Text("正在检查 Codex 限额...")
                .font(CodexStyle.Typography.sectionTitle)
            Text("正在获取 5h、每周和重置额度窗口。")
                .font(.body)
                .foregroundStyle(CodexPalette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Label(footerStatus, systemImage: detail.isCached ? "clock.arrow.circlepath" : "clock")
                .font(.subheadline)
                .foregroundStyle(CodexPalette.secondaryText)

            Spacer()

            if detail.canForget, let snapshotID = detail.snapshotID {
                Button {
                    onForget(snapshotID)
                } label: {
                    Label(detail.isStale ? "忘记过期" : "忘记快照", systemImage: "trash")
                }
            }

            if detail.staleSnapshotCount > 0 {
                Button {
                    onClearStale()
                } label: {
                    Label("清除过期", systemImage: "clock.badge.exclamationmark")
                }
            }

            if cachedAccountCount > 0 {
                Button {
                    onClearCached()
                } label: {
                    Label("清除缓存", systemImage: "xmark.circle")
                }
            }

            Button {
                onRefresh()
            } label: {
                Label(detail.isRefreshing ? "刷新中" : "刷新", systemImage: "arrow.clockwise")
            }
            .disabled(!detail.canRefresh || detail.isRefreshing)
        }
    }

    private var footerStatus: String {
        if detail.isCached {
            return "缓存快照"
        }
        return "每 5 分钟更新"
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 30))
                .foregroundStyle(CodexPalette.secondaryText)
            Text(detail.isCached ? "没有保存重置到期时间。" : "当前没有可用重置。")
                .font(CodexStyle.Typography.sectionTitle)
            Text(detail.isCached ? "这个快照不包含重置额度到期行。" : "Codex 已响应，但重置额度为空。")
                .font(.body)
                .foregroundStyle(CodexPalette.secondaryText)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .codexPanel(shadow: false)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(CodexPalette.warningOrange)
            Text(message)
                .font(.body)
                .foregroundStyle(CodexPalette.primaryText)
                .lineLimit(3)
        }
        .padding(CodexStyle.Spacing.rowVertical)
        .frame(maxWidth: .infinity, alignment: .leading)
        .codexPanel(
            background: CodexPalette.warningOrange.opacity(0.10),
            border: CodexPalette.warningOrange.opacity(0.24),
            shadow: false
        )
    }
}

struct HeaderArtworkView: View {
    var body: some View {
        if let url = Bundle.main.url(forResource: "UsageHeader", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                CodexPalette.rowBackground
                Image(systemName: "terminal.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(CodexPalette.secondaryText)
            }
        }
    }
}

private struct UsageLimitCardView: View {
    let window: UsageLimitDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(window.title, systemImage: iconName)
                    .font(CodexStyle.Typography.cardTitle)
                Spacer()
                Text(percentText(window.remainingPercent))
                    .font(CodexStyle.Typography.cardMetric)
                    .monospacedDigit()
            }

            LimitMeterView(remainingPercent: window.remainingPercent, tint: tint)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    Text("已使用")
                        .foregroundStyle(CodexPalette.secondaryText)
                    Text(percentText(window.usedPercent))
                        .monospacedDigit()
                }
                GridRow {
                    Text("距离重置")
                        .foregroundStyle(CodexPalette.secondaryText)
                    Text(DateFormatting.duration(seconds: window.window.resetAfterSeconds))
                }
                GridRow {
                    Text("重置时间")
                        .foregroundStyle(CodexPalette.secondaryText)
                    Text(DateFormatting.weekdayCompact(window.window.resetDate))
                }
            }
            .font(.subheadline)
        }
        .padding(CodexStyle.Spacing.panel)
        .codexPanel()
    }

    private var iconName: String {
        switch window.kind {
        case .fiveHour:
            return "clock"
        case .weekly:
            return "calendar"
        case .generic:
            return "gauge"
        }
    }

    private var tint: Color {
        guard let remaining = window.remainingPercent else {
            return CodexPalette.secondaryText
        }
        if remaining <= 15 {
            return CodexPalette.urgentRed
        }
        if remaining <= 30 {
            return CodexPalette.warningOrange
        }
        return CodexPalette.availableGreen
    }

    private func percentText(_ value: Int?) -> String {
        guard let value else {
            return "-"
        }
        return "\(value)%"
    }
}

private struct LimitMeterView: View {
    let remainingPercent: Int?
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: CodexStyle.Radius.pill, style: .continuous)
                    .fill(CodexPalette.meterTrack)
                RoundedRectangle(cornerRadius: CodexStyle.Radius.pill, style: .continuous)
                    .fill(tint)
                    .frame(width: proxy.size.width * clampedValue)
            }
        }
        .frame(height: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("剩余")
        .accessibilityValue(remainingPercent.map { "\($0)%" } ?? "未知")
    }

    private var clampedValue: CGFloat {
        let value = CGFloat(max(0, min(100, remainingPercent ?? 0)))
        return value / 100
    }
}

private struct NudgeCardView: View {
    let nudge: UsageNudge

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(nudge.title)
                        .font(CodexStyle.Typography.cardTitle)
                    Spacer()
                    Text(nudge.detail)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CodexPalette.secondaryText)
                        .lineLimit(1)
                }

                Text(nudge.message)
                    .font(.subheadline)
                    .foregroundStyle(CodexPalette.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(CodexStyle.Spacing.panel)
        .codexPanel(border: tint.opacity(0.28))
    }

    private var iconName: String {
        switch nudge.tier {
        case .spend:
            return "bolt.fill"
        case .expiringReset:
            return "exclamationmark.octagon.fill"
        case .deadline:
            return "bolt.badge.clock"
        case .useIfBlocked:
            return "bolt.badge.clock"
        case .waitFiveHour:
            return "hourglass"
        case .hold:
            return "shield.fill"
        case .steady:
            return "gauge"
        case .noResets:
            return "exclamationmark.triangle.fill"
        case .unavailable:
            return "questionmark.circle"
        }
    }

    private var tint: Color {
        switch nudge.tier {
        case .spend:
            return CodexPalette.availableGreen
        case .expiringReset:
            return CodexPalette.urgentRed
        case .deadline:
            return CodexPalette.warningOrange
        case .useIfBlocked:
            return CodexPalette.warningOrange
        case .waitFiveHour, .hold, .steady:
            return CodexPalette.accent
        case .noResets, .unavailable:
            return CodexPalette.secondaryText
        }
    }
}
