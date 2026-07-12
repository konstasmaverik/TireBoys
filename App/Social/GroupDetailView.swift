import SwiftUI

struct GroupDetailView: View {
    let backend: Backend
    let group: FriendGroup

    @Environment(\.dismiss) private var dismiss
    @State private var entries: [LeaderboardEntry] = []
    @State private var metric: Metric = .topSpeed
    @State private var period: StatsView.Period = .week

    enum Metric: String, CaseIterable, Identifiable {
        case topSpeed = "Top speed"
        case distance = "Distance"
        case timeInCar = "Time in car"

        var id: Self { self }

        func value(of entry: LeaderboardEntry) -> Double {
            switch self {
            case .topSpeed: entry.topSpeedMetersPerSecond
            case .distance: entry.totalDistanceMeters
            case .timeInCar: entry.totalDurationSeconds
            }
        }

        func formatted(_ entry: LeaderboardEntry) -> String {
            switch self {
            case .topSpeed: Format.kilometersPerHour(entry.topSpeedMetersPerSecond) + " km/h"
            case .distance: Format.kilometers(entry.totalDistanceMeters)
            case .timeInCar: Format.duration(entry.totalDurationSeconds)
            }
        }
    }

    private var ranked: [LeaderboardEntry] {
        entries.sorted { metric.value(of: $0) > metric.value(of: $1) }
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
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.username)
                                .font(entry.id == backend.profile?.id ? .body.bold() : .body)
                            Text("\(entry.driveCount) drives")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(metric.formatted(entry))
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
        .refreshable { await reload() }
    }

    private func reload() async {
        entries = (try? await backend.leaderboard(for: group.id, since: period.cutoff)) ?? entries
    }
}
