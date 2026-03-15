import SwiftUI

struct PRDListView: View {
    @Bindable var state: ProjectState

    var body: some View {
        List(state.prds) { prd in
            NavigationLink(value: NavigationDestination.prdPreview(prd)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(prd.title)
                        .font(.headline)
                    Text(prd.preview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    if let ts = state.taskSet(for: prd) {
                        HStack(spacing: 8) {
                            ProgressView(value: ts.progress)
                                .tint(ts.isAllDone ? .green : .accentColor)
                            Text("\(ts.completedCount)/\(ts.totalCount) done")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .navigationTitle("PRDs")
        .overlay {
            if state.prds.isEmpty {
                ContentUnavailableView {
                    Label("No PRDs", systemImage: "doc.text")
                } description: {
                    Text("Press ⌘N to create a new PRD.")
                }
            }
        }
    }
}
