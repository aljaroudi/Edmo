import SwiftUI

struct PRDPreviewView: View {
    let prd: PRDFile
    @Bindable var state: ProjectState
    @State private var isEditing = false
    @State private var editableContent: String = ""

    private var matchingTaskSet: TaskSet? {
        state.taskSet(for: prd)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress header if linked task set exists
            if let ts = matchingTaskSet {
                HStack {
                    Text("\(ts.completedCount) of \(ts.totalCount) stories done")
                        .font(.headline)
                    Spacer()
                    ProgressView(value: ts.progress)
                        .frame(width: 200)
                        .tint(ts.isAllDone ? .green : .accentColor)
                }
                .padding()
                Divider()
            }

            if isEditing {
                TextEditor(text: $editableContent)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
            } else {
                ScrollView {
                    Text(renderedMarkdown)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
        }
        .navigationTitle(prd.title)
        .onAppear {
            editableContent = prd.content
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    if isEditing {
                        // Save
                        state.savePRD(content: editableContent, to: prd.url)
                    }
                    isEditing.toggle()
                } label: {
                    Label(
                        isEditing ? "Preview" : "Edit",
                        systemImage: isEditing ? "eye" : "pencil"
                    )
                }

                if isEditing {
                    Button("Save") {
                        state.savePRD(content: editableContent, to: prd.url)
                        isEditing = false
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button("Extract Tasks") {
                    extractTasks()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [.command, .shift])
                .disabled(state.selectedCLI == nil)
            }
        }
    }

    private var renderedMarkdown: AttributedString {
        do {
            var options = AttributedString.MarkdownParsingOptions()
            options.interpretedSyntax = .inlineOnlyPreservingWhitespace
            return try AttributedString(markdown: prd.content, options: options)
        } catch {
            return AttributedString(prd.content)
        }
    }

    private func extractTasks() {
        let slug = prd.url.deletingPathExtension().lastPathComponent
        let prdRelPath = ".edmo/prd/\(prd.url.lastPathComponent)"
        let tasksRelPath = ".edmo/tasks/\(slug).json"

        state.launchCommand(
            action: .extractTasks,
            context: CommandContext(
                slug: slug,
                prdPath: prdRelPath,
                tasksPath: tasksRelPath
            )
        )
    }
}
