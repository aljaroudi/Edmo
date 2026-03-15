import SwiftUI

struct DashboardView: View {
    @Bindable var state: ProjectState

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !state.hasProject {
                    emptyState
                } else {
                    cardsGrid
                }
            }
            .padding()
        }
        .navigationTitle("Dashboard")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Project Open")
                .font(.title2)
            Text("Open a project folder to get started.")
                .foregroundStyle(.secondary)
            Button("Open Project...") {
                state.promptForProject()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
    }

    private var cardsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 16)], spacing: 16) {
            DashboardCard(
                title: "Open Issues",
                value: "\(state.issues.filter(\.isOpen).count)",
                icon: "exclamationmark.circle",
                color: .orange
            )
            DashboardCard(
                title: "PRDs",
                value: "\(state.prds.count)",
                icon: "doc.text",
                color: .blue
            )
            ForEach(state.taskSets) { ts in
                DashboardCard(
                    title: ts.description,
                    value: "\(ts.completedCount)/\(ts.totalCount)",
                    icon: "checklist",
                    color: ts.isAllDone ? .green : .purple,
                    progress: ts.progress
                )
            }
        }
    }
}

struct DashboardCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var progress: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let progress {
                ProgressView(value: progress)
                    .tint(color)
            }
        }
        .padding()
        .frame(maxHeight: .infinity)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary))
    }
}
