import SwiftUI

struct OnboardingView: View {
    @State var viewModel = OnboardingViewModel()
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            progressDots
                .padding(.top, 24)

            Spacer()

            // Step content with animated transitions
            Group {
                switch viewModel.currentStep {
                case .welcome:
                    OnboardingWelcomeStep()
                case .permissions:
                    OnboardingPermissionStep(viewModel: viewModel)
                case .shortcut:
                    OnboardingShortcutStep(viewModel: viewModel)
                case .preferences:
                    OnboardingPreferencesStep(viewModel: viewModel)
                case .ready:
                    OnboardingReadyStep(viewModel: viewModel)
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: viewModel.currentStep)

            Spacer()

            // Navigation buttons
            navigationBar
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 40)
        .frame(width: 600, height: 500)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .controlBackgroundColor),
                    Color(nsColor: .controlBackgroundColor).opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Progress Dots

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                Circle()
                    .fill(step.rawValue <= viewModel.stepIndex
                          ? Color.accentColor
                          : Color.secondary.opacity(0.3))
                    .frame(width: step == viewModel.currentStep ? 10 : 7,
                           height: step == viewModel.currentStep ? 10 : 7)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.currentStep)
            }
        }
    }

    // MARK: - Navigation

    private var navigationBar: some View {
        HStack {
            if !viewModel.isFirstStep && !viewModel.isLastStep {
                Button("Back") {
                    withAnimation { viewModel.previousStep() }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Spacer()

            if !viewModel.isLastStep {
                Button("Skip") {
                    viewModel.skipOnboarding()
                    onComplete()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .controlSize(.large)
            }

            if viewModel.isLastStep {
                Button("Start Using OpenPaste") {
                    viewModel.completeOnboarding()
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button(viewModel.isFirstStep ? "Get Started" : "Continue") {
                    withAnimation { viewModel.nextStep() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.canProceed)
            }
        }
    }
}
