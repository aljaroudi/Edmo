import SwiftUI

struct SettingsView: View {
    @Bindable var state: ProjectState

    var body: some View {
        Form {
            Section("CLI Tools") {
                if state.detectedCLITools.isEmpty {
                    Label("No CLI tools detected. Install 'claude' or 'codex' and ensure they are in your PATH.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                } else {
                    Picker("Default CLI Tool", selection: $state.selectedCLI) {
                        ForEach(state.detectedCLITools) { tool in
                            Text(tool.displayName).tag(Optional(tool))
                        }
                    }
                }

                HStack {
                    Text("gh CLI")
                    Spacer()
                    if state.ghAvailable {
                        Label("Available", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Not found", systemImage: "xmark.circle")
                            .foregroundStyle(.red)
                    }
                }
            }

            Section("Terminal") {
                Picker("Terminal App", selection: $state.selectedTerminal) {
                    ForEach(TerminalApp.allCases) { app in
                        Text(app.rawValue).tag(app)
                    }
                }
            }

            Section("Project") {
                if let path = state.projectPath {
                    LabeledContent("Path", value: path)
                } else {
                    Text("No project open")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Save Settings") {
                    state.saveConfig()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}
