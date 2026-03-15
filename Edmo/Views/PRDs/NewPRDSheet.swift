import SwiftUI

struct NewPRDSheet: View {
    @Bindable var state: ProjectState
    @Environment(\.dismiss) private var dismiss
    @State private var ideaText = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("New PRD")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Describe your idea. A CLI tool will generate the PRD.")
                .foregroundStyle(.secondary)
                .font(.callout)

            TextEditor(text: $ideaText)
                .frame(minHeight: 100)
                .font(.body)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create PRD") {
                    createPRD()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(ideaText.trimmingCharacters(in: .whitespaces).isEmpty || state.selectedCLI == nil)
            }
        }
        .padding()
        .frame(width: 480)
    }

    private func createPRD() {
        let slug = CommandBuilder.slugify(ideaText)
        state.launchCommand(
            action: .createPRD,
            context: CommandContext(slug: slug, ideaText: ideaText)
        )
    }
}
