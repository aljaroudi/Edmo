import SwiftUI

struct ShortcutCheatSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Keyboard Shortcuts")
                .font(.title2)
                .fontWeight(.semibold)

            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                shortcutRow("⌘1", "Dashboard")
                shortcutRow("⌘2", "Work")
                shortcutRow("⌘3", "PRDs")
                Divider().gridCellUnsizedAxes(.horizontal)
                shortcutRow("⌘K", "Command Palette")
                shortcutRow("⌘N", "New PRD")
                shortcutRow("⌘R", "Refresh")
                shortcutRow("⌘,", "Settings")
                Divider().gridCellUnsizedAxes(.horizontal)
                shortcutRow("⌘↩", "Implement (on issue)")
                shortcutRow("⌘⇧↩", "Extract Tasks (on PRD)")
                shortcutRow("⌘D", "Toggle story status")
                shortcutRow("⌘I", "Create issue from story")
                shortcutRow("⌘⇧I", "Create all issues")
                shortcutRow("⌘⌫", "Clean up completed tasks")
                shortcutRow("⌘/", "This cheat sheet")
            }

            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding()
        .frame(width: 380)
    }

    @ViewBuilder
    private func shortcutRow(_ shortcut: String, _ desc: String) -> some View {
        GridRow {
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .frame(width: 80, alignment: .trailing)
            Text(desc)
        }
    }
}
