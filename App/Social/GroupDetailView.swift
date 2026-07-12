import SwiftUI

struct GroupDetailView: View {
    let backend: Backend
    let group: FriendGroup

    @Environment(\.dismiss) private var dismiss
    @State private var entries: [LeaderboardEntry] = []
    @State private var metric: Metric = .topSpeed
    @State private var period: StatsView.Period = .week
    @AppStorage(Format.useMilesKey) private var useMiles = false

    enum Metric: String, CaseIterable, Identifiable {
        case overall = "Overall"
        case topSpeed = "Top speed"
        case distance = "Distance"
        case timeInCar = "Time in car"

        var id: Self { self }

        func value(of entry: LeaderboardEntry) -> Double {
            switch self {
            case .overall: 0 // ranked via overallScore, which needs the whole group
            case .topSpeed: entry.topSpeedMetersPerSecond
            case .distance: entry.totalDistanceMeters
            case .timeInCar: entry.totalDurationSeconds
            }
        }
    }

    /// Overall = each metric scored against the group's best (0–100),
    /// averaged. The best all-rounder wins, not just the fastest.
    private func overallScore(_ entry: LeaderboardEntry, in group: [LeaderboardEntry]) -> Double {
        let metrics: [Metric] = [.topSpeed, .distance, .timeInCar]
        let shares = metrics.compactMap { metric -> Double? in
            guard let best = group.map({ metric.value(of: $0) }).max(), best > 0 else { return nil }
            return metric.value(of: entry) / best
        }
        guard !shares.isEmpty else { return 0 }
        return shares.reduce(0, +) / Double(shares.count) * 100
    }

    private func score(_ entry: LeaderboardEntry) -> Double {
        metric == .overall ? overallScore(entry, in: entries) : metric.value(of: entry)
    }

    private func formattedScore(_ entry: LeaderboardEntry) -> String {
        switch metric {
        case .overall: String(format: "%.0f pts", overallScore(entry, in: entries))
        case .topSpeed: Format.speedWithUnit(entry.topSpeedMetersPerSecond)
        case .distance: Format.distance(entry.totalDistanceMeters)
        case .timeInCar: Format.duration(entry.totalDurationSeconds)
        }
    }

    private var ranked: [LeaderboardEntry] {
        entries.sorted { score($0) > score($1) }
    }

    var body: some View {
        List {
            Section {
                Picker("Metric", selection: $metric) {
                    ForEach(Metric.allCases) { metric in
                        Text(metric.rawValue).tag(metric)
                    }
                }
                Picker("Period", selection: $period) {
                    ForEach(StatsView.Period.allCases) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Ranking") {
                ForEach(Array(ranked.enumerated()), id: \.element.id) { rank, entry in
                    HStack(spacing: 12) {
                        Text("\(rank + 1)")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(rank == 0 ? .yellow : .secondary)
                            .frame(width: 28)
                        AvatarView(urlString: entry.avatarURL, fallbackName: entry.username)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.username)
                                .font(entry.id == backend.profile?.id ? .body.bold() : .body)
                            Text("\(entry.driveCount) drives")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(formattedScore(entry))
                            .font(.body.monospacedDigit())
                    }
                }
            }

            Section {
                LabeledContent("Invite code") {
                    Text(group.inviteCode)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                }
                ShareLink(item: "Join my DriveStats group \"\(group.name)\" with invite code: \(group.inviteCode)") {
                    Label("Share invite", systemImage: "square.and.arrow.up")
                }
                Button("Leave group", role: .destructive) {
                    Task {
                        try? await backend.leaveGroup(group.id)
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: period) { await reload() }
        .task {
            // The README promised live-ish leaderboards; polling every 30 s
            // is plenty for a friend-group ranking.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                await reload()
            }
        }
        .refreshable { await reload() }
    }

    private func reload() async {
        entries = (try? await backend.leaderboard(for: group.id, since: period.cutoff)) ?? entries
    }
}
