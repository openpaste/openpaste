import SwiftUI

struct FeedbackFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var viewModel: FeedbackViewModel
    @State private var showOpenError = false

    init(router: FeedbackRouterProtocol) {
        _viewModel = State(initialValue: FeedbackViewModel(router: router))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Send Feedback")
                    .font(.title2.weight(.semibold))

                Text("Nothing is sent automatically. OpenPaste only opens a draft in \(viewModel.destination.label) so you can review and edit it first.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Form {
                Section("Basics") {
                    Picker("Category", selection: $viewModel.category) {
                        ForEach(FeedbackCategory.allCases) { category in
                            Text(category.title).tag(category)
                        }
                    }

                    Picker("Install method", selection: $viewModel.installMethod) {
                        ForEach(FeedbackInstallMethod.allCases) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }

                    TextField(viewModel.category.summaryPlaceholder, text: $viewModel.summary)
                }

                Section("Details") {
                    editor(viewModel.category.workflowPrompt, text: $viewModel.workflow)
                    editor(viewModel.category.expectationPrompt, text: $viewModel.expectedHelp)
                    editor(viewModel.category.actualPrompt, text: $viewModel.actualResult)
                    editor(viewModel.category.blockersPrompt, text: $viewModel.blockers, required: false)
                }

                if viewModel.category == .praise {
                    Section("Optional quote") {
                        Toggle("Okay to quote positive feedback publicly", isOn: $viewModel.publicQuoteAllowed)

                        if viewModel.publicQuoteAllowed {
                            TextField("Optional one-line quote", text: $viewModel.publicQuote)
                        }
                    }
                }

                Section("Included metadata") {
                    LabeledContent("OpenPaste version") { Text(viewModel.appVersion) }
                    LabeledContent("macOS version") { Text(viewModel.macOSVersion) }
                    LabeledContent("Destination") { Text(viewModel.destination.label) }
                    Text(viewModel.destination.guidance)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            HStack(spacing: DS.Spacing.md) {
                Button("Cancel") {
                    dismiss()
                }

                Spacer()

                Button(viewModel.submitTitle) {
                    openURL(viewModel.destination.url) { accepted in
                        if accepted {
                            viewModel.reset()
                            dismiss()
                        } else {
                            showOpenError = true
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canSubmit)
            }
        }
        .padding(DS.Spacing.xl)
        .frame(width: 520, height: 640)
        .onChange(of: viewModel.category) { _, newValue in
            guard newValue != .praise else { return }
            viewModel.publicQuoteAllowed = false
            viewModel.publicQuote = ""
        }
        .alert("Couldn’t open \(viewModel.destination.label)", isPresented: $showOpenError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your draft is still here. Please try again, or use the feedback template manually.")
        }
    }

    private func editor(
        _ title: String,
        text: Binding<String>,
        required: Bool = true
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                Text(title)
                    .font(.subheadline.weight(.medium))

                if required {
                    Text("Required")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.Colors.accent)
                }
            }

            TextEditor(text: text)
                .font(.body)
                .frame(minHeight: required ? 84 : 64)
                .padding(DS.Spacing.xs)
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .strokeBorder(Color.secondary.opacity(0.2))
                }
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}