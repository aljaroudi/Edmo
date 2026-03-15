import SwiftUI

struct SidebarView: View {
    @Bindable var state: ProjectState

    var body: some View {
        List {
            Section("Projects") {
                ForEach(state.projects) { project in
                    projectRow(project)
                }
                Button {
                    state.promptForProject()
                } label: {
                    Label("Add Project", systemImage: "plus")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 250)
    }

    @ViewBuilder
    private func projectRow(_ project: ProjectInfo) -> some View {
        let isCurrent = project.id == state.currentProject?.id
        Button {
            state.openProject(path: project.path)
        } label: {
            HStack {
                Image(systemName: "folder")
                    .foregroundStyle(isCurrent ? Color.accentColor : Color.secondary)
                Text(project.displayName)
                    .fontWeight(isCurrent ? .semibold : .regular)
                Spacer()
                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Remove from List", role: .destructive) {
                state.removeProject(id: project.id)
            }
        }
    }
}
