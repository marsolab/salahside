import SwiftUI

struct MembershipPaywallView: View {
    let session: PrayerFocusSession
    @Environment(MembershipStore.self) private var membership
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan = MembershipPlan.yearly
    @State private var secondarySheet: SecondarySheet?
    @ScaledMetric(relativeTo: .largeTitle) private var headlineSize = 42.0
    @ScaledMetric(relativeTo: .body) private var bodySize = 15.0

    var body: some View {
        @Bindable var membership = membership

        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    hero(
                        width: geometry.size.width,
                        height: min(
                            geometry.size.width * 0.875,
                            max(200, geometry.size.height + geometry.safeAreaInsets.top - 485))
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Make space\nfor salah.")
                            .font(.system(size: headlineSize, weight: .bold))
                            .tracking(-1.2)
                            .foregroundStyle(PrayerTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)

                        Text(
                            membership.hasThreeDayTrial(for: selectedPlan)
                                ? "Your setup is ready. Try SalahSide free for 3 days."
                                : "Your setup is ready. Choose your membership."
                        )
                        .font(.system(size: bodySize))
                        .foregroundStyle(PrayerTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)

                        VStack(alignment: .leading, spacing: 8) {
                            benefit("Selected apps pause automatically")
                            benefit("Focus for all five prayers")
                        }
                        .padding(.top, 16)

                        VStack(spacing: 8) {
                            ForEach(MembershipPlan.allCases) { plan in
                                planRow(plan)
                            }
                        }
                        .padding(.top, 16)

                        Button {
                            Task { await membership.subscribe(to: selectedPlan) }
                        } label: {
                            ZStack {
                                Text(membership.purchaseTitle(for: selectedPlan))
                                    .font(.system(size: 18, weight: .semibold))
                                HStack {
                                    Spacer()
                                    if membership.isBusy {
                                        ProgressView().tint(.white)
                                    } else {
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 18, weight: .medium))
                                    }
                                }
                                .padding(.horizontal, 18)
                            }
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .foregroundStyle(.white)
                            .background(PrayerTheme.sage, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .disabled(membership.isBusy || membership.isLoadingProducts)
                        .accessibilityIdentifier("membership.subscribe")
                        .padding(.top, 12)

                        VStack(spacing: 4) {
                            Text(membership.billingDisclosure(for: selectedPlan))
                                .fontWeight(.medium)
                                .accessibilityIdentifier("membership.billingDisclosure")
                            Text("Auto-renews unless cancelled in Apple Account settings.")
                        }
                        .font(.system(size: 12.5))
                        .foregroundStyle(PrayerTheme.secondaryInk)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)

                        Button("Review your setup") { secondarySheet = .settings }
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(PrayerTheme.sage)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .buttonStyle(.plain)
                            .disabled(membership.isBusy)
                            .accessibilityIdentifier("membership.reviewSetup")

                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 4)
                }
            }
            .contentMargins(.top, 0, for: .scrollContent)
            .scrollIndicators(.hidden)
            .ignoresSafeArea(.container, edges: .top)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footer
                .padding(.horizontal, 24)
                .padding(.vertical, 4)
                .background(PrayerTheme.canvas)
        }
        .background(PrayerTheme.canvas.ignoresSafeArea())
        .onChange(of: membership.hasAccess) { _, hasAccess in
            if hasAccess {
                dismiss()
            }
        }
        .alert(item: $membership.message) { message in
            Alert(
                title: Text(message.title),
                message: Text(message.detail),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(item: $secondarySheet) { sheet in
            switch sheet {
            case .privacy:
                MembershipPrivacyView()
            case .settings:
                FocusSettingsView(session: session, allowsPrayerActions: false)
            }
        }
    }

    private func hero(width: CGFloat, height: CGFloat) -> some View {
        Image("PaywallMosque")
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height, alignment: .top)
            .clipped()
            .overlay(alignment: .bottom) {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: PrayerTheme.canvas.opacity(0.25), location: 0.4),
                        .init(color: PrayerTheme.canvas, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: min(96, height * 0.35))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
    }

    private func benefit(_ title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(PrayerTheme.sageDark)
                .frame(width: 28, height: 28)
                .background(PrayerTheme.sageSoft, in: Circle())
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: bodySize))
                .foregroundStyle(PrayerTheme.ink)
        }
    }

    private func planRow(_ plan: MembershipPlan) -> some View {
        let isSelected = selectedPlan == plan
        return Button {
            selectedPlan = plan
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(isSelected ? PrayerTheme.sage : PrayerTheme.secondaryInk.opacity(0.65))
                    .accessibilityHidden(true)
                Text(plan.title)
                    .font(.system(size: 16, weight: .medium))
                if plan == .yearly && membership.yearlyIsBestValue {
                    Text("Best value")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(PrayerTheme.sageDark)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(PrayerTheme.sageSoft, in: Capsule())
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(membership.price(for: plan))/\(plan.period)")
                        .font(.system(size: 18, weight: .semibold))
                    if plan == .yearly, let equivalent = membership.monthlyPrice(for: plan) {
                        Text("\(equivalent)/month")
                            .font(.caption)
                            .foregroundStyle(PrayerTheme.secondaryInk)
                    }
                }
            }
            .foregroundStyle(PrayerTheme.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 58)
            .contentShape(Rectangle())
            .background(PrayerTheme.surface.opacity(isSelected ? 0.7 : 0), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? PrayerTheme.sage : PrayerTheme.hairline, lineWidth: isSelected ? 1.3 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(plan.title), \(membership.billingDisclosure(for: plan))")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("membership.plan.\(plan.rawValue)")
        .disabled(membership.isBusy)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Button("Restore purchases") {
                Task { await membership.restore() }
            }
            .frame(minHeight: 44)
            .accessibilityIdentifier("membership.restore")
            .disabled(membership.isBusy)
            Spacer(minLength: 4)
            Link(
                "Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
            )
            .frame(minHeight: 44)
            Button("Privacy") { secondarySheet = .privacy }
                .frame(minHeight: 44)
        }
        .font(.system(size: 12))
        .foregroundStyle(PrayerTheme.secondaryInk)
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }

    private enum SecondarySheet: String, Identifiable {
        case privacy
        case settings
        var id: String { rawValue }
    }
}

struct MembershipPrivacyView: View {
    private var policyURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SalahSidePrivacyPolicyURL") as? String,
            let url = URL(string: raw), url.scheme == "https", let host = url.host, !host.isEmpty
        else { return nil }
        return url
    }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Your prayer check-ins are saved locally.")
                        .font(.title2.weight(.semibold))
                    Text(
                        "SalahSide does not require an account. Prayer check-ins and app selections are used on this device for the focus experience."
                    )
                    Text(
                        "Settings, check-ins and opaque app-selection tokens are stored locally and may be included in your device backups. You can erase them in Settings. SalahSide does not upload them or use advertising trackers."
                    )
                    if let policyURL {
                        Link("Read the full privacy policy", destination: policyURL)
                    }
                    Text("Apple processes subscription payments. SalahSide does not receive your payment card details.")
                    Text(
                        "Optional prayer mat unlock uses the camera and compares photos on this iPhone. SalahSide saves only a comparison fingerprint, not the photos, and never uploads either. Remove your mat or erase local data in Settings."
                    )
                }
                .padding(24)
            }
            .font(.body)
            .foregroundStyle(PrayerTheme.ink)
            .background(PrayerTheme.canvas.ignoresSafeArea())
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(PrayerTheme.sage)
    }
}

#Preview {
    MembershipPaywallView(session: PrayerFocusSession())
        .environment(MembershipStore())
        .environment(FocusConfiguration())
        .environment(ScreenTimeService())
        .environment(
            RegisteredMatStore(
                directory: FileManager.default.temporaryDirectory.appendingPathComponent("MatPaywallPreview")))
}
