import SwiftUI
import MapKit

struct RouteBuilderView: View {

    @StateObject private var vm      = RouteBuilderViewModel()
    @State private var showWaypoints = false
    @State private var shareURL      : URL? = nil
    @State private var showClearAlert = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {

                // MARK: Map
                RouteMapView(vm: vm)
                    .ignoresSafeArea()

                // MARK: Routing spinner
                if vm.isRouting {
                    VStack {
                        HStack(spacing: 10) {
                            ProgressView()
                                .tint(.white)
                            Text("Snapping to road...")
                                .font(.system(size: 12,
                                              weight: .medium,
                                              design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(20)
                        .padding(.top, 60)
                        Spacer()
                    }
                }

                // MARK: Error banner
                if let err = vm.errorMessage {
                    VStack {
                        HStack(spacing: 8) {
                            Image(systemName:
                                    "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(err)
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                                .fixedSize(horizontal: false,
                                           vertical: true)
                        }
                        .padding(14)
                        .background(Color.black.opacity(0.80))
                        .cornerRadius(14)
                        .padding(.horizontal, 20)
                        .padding(.top, 60)
                        Spacer()
                    }
                }

                // MARK: Bottom panel
                VStack(spacing: 0) {
                    statsBar
                    controlBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("ROUTE BUILDER")
                        .font(.system(size: 12, weight: .semibold,
                                      design: .monospaced))
                        .foregroundColor(.secondary)
                        .kerning(3)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showWaypoints.toggle()
                    } label: {
                        Image(systemName: "list.bullet")
                            .foregroundColor(.primary)
                    }
                    .disabled(vm.waypoints.isEmpty)
                }
            }
            .sheet(isPresented: $showWaypoints) {
                waypointSheet
            }
            .sheet(item: $shareURL) { url in
                ShareSheet(items: [url])
            }
            .alert("Clear Route",
                   isPresented: $showClearAlert) {
                Button("Clear", role: .destructive) { vm.clearAll() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all waypoints and start over.")
            }
        }
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 0) {
            statCell(
                value: String(format: "%.2f", vm.totalMiles),
                unit:  "mi",
                icon:  "arrow.left.and.right"
            )
            Divider().frame(height: 32)
            statCell(
                value: String(format: "%.1f", vm.totalKm),
                unit:  "km",
                icon:  "arrow.left.and.right"
            )
            Divider().frame(height: 32)
            statCell(
                value: String(format: "%.0f", vm.totalAscentFeet),
                unit:  "ft gain",
                icon:  "arrow.up.right"
            )
            Divider().frame(height: 32)
            statCell(
                value: "\(vm.waypoints.count)",
                unit:  "points",
                icon:  "mappin"
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private func statCell(value: String, unit: String,
                           icon: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .thin,
                              design: .monospaced))
                .foregroundColor(.primary)
            Text(unit)
                .font(.system(size: 9, weight: .medium,
                              design: .monospaced))
                .foregroundColor(.secondary)
                .kerning(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: 12) {

            // Center on user
            circleButton(icon: "location.fill",
                         color: Color(hex: "0A84FF")) {
                vm.centerOnUser()
            }

            // Undo
            circleButton(icon: "arrow.uturn.backward",
                         color: .primary,
                         disabled: !vm.canUndo) {
                vm.undoLast()
            }

            // Clear
            circleButton(icon: "trash",
                         color: Color(hex: "FF453A"),
                         disabled: vm.waypoints.isEmpty) {
                showClearAlert = true
            }

            Spacer()

            // Instruction label
            if vm.waypoints.isEmpty {
                Text("Tap the map to start")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
            } else {
                Text("Tap to add points")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Export GPX
            Button {
                if let url = vm.buildGPX() {
                    shareURL = url
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .medium))
                    Text("GPX")
                        .font(.system(size: 12, weight: .semibold,
                                      design: .monospaced))
                }
                .foregroundColor(vm.canExport
                                 ? Color(.systemBackground)
                                 : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(vm.canExport
                            ? Color(.label)
                            : Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
            .disabled(!vm.canExport)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }

    private func circleButton(icon: String,
                               color: Color,
                               disabled: Bool = false,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(disabled ? .secondary : color)
                .frame(width: 42, height: 42)
                .background(Color(.secondarySystemBackground))
                .clipShape(Circle())
        }
        .disabled(disabled)
    }

    // MARK: - Waypoint Sheet

    private var waypointSheet: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                if vm.waypoints.isEmpty {
                    Text("No waypoints yet.\nTap the map to begin.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    List {
                        ForEach(Array(vm.waypoints.enumerated()),
                                id: \.element.id) { i, wp in
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(i == 0
                                              ? Color(hex: "30D158")
                                              : i == vm.waypoints.count - 1
                                                ? Color(hex: "FF453A")
                                                : Color(hex: "0A84FF"))
                                        .frame(width: 28, height: 28)
                                    Text("\(i + 1)")
                                        .font(.system(size: 11,
                                                      weight: .bold,
                                                      design: .monospaced))
                                        .foregroundColor(.white)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(i == 0
                                         ? "Start"
                                         : i == vm.waypoints.count - 1
                                            ? "End"
                                            : "Point \(i + 1)")
                                        .font(.system(size: 14,
                                                      weight: .medium))
                                        .foregroundColor(.primary)
                                    Text(String(format: "%.5f, %.5f",
                                                wp.coordinate.latitude,
                                                wp.coordinate.longitude))
                                        .font(.system(size: 10,
                                                      design: .monospaced))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if i < vm.segments.count {
                                    Text(String(format: "+%.1f mi",
                                                vm.segments[i].distanceM / 1609.344))
                                        .font(.system(size: 11,
                                                      design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Waypoints")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showWaypoints = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(
        context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items,
                                 applicationActivities: nil)
    }
    func updateUIViewController(
        _ vc: UIActivityViewController, context: Context) {}
}
