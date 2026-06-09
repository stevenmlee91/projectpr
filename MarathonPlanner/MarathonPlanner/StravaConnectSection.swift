import SwiftUI

// MARK: - Strava Connect Section
//
// Shown inside SettingsView under "Integrations".
// Handles connect, disconnect, and manual sync.

struct StravaConnectSection: View {
    @EnvironmentObject var stravaService : StravaService
    @EnvironmentObject var store         : PlanStore

    @State private var showDisconnectConfirm = false

    var body: some View {
        Section {
            if stravaService.isConnected {
                connectedRow
                if let error = stravaService.syncError {
                    errorRow(error)
                }
                disconnectRow
            } else {
                connectRow
            }
        } header: {
            Text("Integrations")
        } footer: {
            if !stravaService.isConnected {
                Text("Connect Strava to automatically match GPS runs to your planned workouts. Mile Zero only reads your activities — it never posts anything.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else if let date = stravaService.lastSyncDate {
                Text("Last synced \(date.formatted(.relative(presentation: .named))).")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .listRowBackground(Color(.secondarySystemGroupedBackground))
        .confirmationDialog(
            "Disconnect Strava?",
            isPresented: $showDisconnectConfirm,
            titleVisibility: .visible
        ) {
            Button("Disconnect", role: .destructive) {
                stravaService.disconnect()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your plan data stays intact. Strava tokens are deleted from this device.")
        }
    }

    // MARK: - Connect row

    private var connectRow: some View {
        Button {
            Task { await stravaService.connect() }
        } label: {
            HStack(spacing: 14) {
                stravaIcon(connected: false)
                Text("Connect Strava")
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Connected row

    private var connectedRow: some View {
        HStack(spacing: 14) {
            stravaIcon(connected: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(stravaService.athleteName.isEmpty
                     ? "Connected" : stravaService.athleteName)
                    .foregroundColor(.primary)
                Text("Strava connected")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
            if stravaService.isSyncing {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button("Sync Now") {
                    Task { await stravaService.sync(plans: store.plans) }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "FC4C02"))
            }
        }
    }

    // MARK: - Error row

    private func errorRow(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "FF453A"))
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "FF453A"))
        }
        .padding(.vertical, 2)
    }

    // MARK: - Disconnect row

    private var disconnectRow: some View {
        Button {
            showDisconnectConfirm = true
        } label: {
            HStack {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "FF453A"))
                Text("Disconnect Strava")
                    .foregroundColor(Color(hex: "FF453A"))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Strava icon

    private func stravaIcon(connected: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(Color(hex: "FC4C02"))
                .frame(width: 28, height: 28)
            if connected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Text("S")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}
