import SwiftUI
import MapKit

struct RouteBuilderView: View {

    @StateObject private var vm       = RouteBuilderViewModel()
    @State private var showWaypoints  = false
    @State private var shareURL       : URL? = nil
    @State private var showClearAlert = false
    @State private var showElevation  = false
    @State private var showSearch     = false
    @State private var searchQuery    = ""
    @State private var searchResults  : [MKMapItem] = []
    @State private var isSearching    = false

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
                            Image(systemName: "exclamationmark.triangle.fill")
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.primary)
                    }
                }
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
            .sheet(isPresented: $showSearch) {
                locationSearchSheet
            }
            .sheet(isPresented: $showWaypoints) {
                waypointSheet
            }
            .sheet(item: $shareURL) { url in
                ShareSheet(items: [url])
            }
            .sheet(isPresented: $showElevation) {
                ElevationSheetView(
                    segments:    vm.segments,
                    totalMiles:  vm.totalMiles,
                    isPresented: $showElevation
                )
            }
            .alert("Clear Route", isPresented: $showClearAlert) {
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
            statCell(value: String(format: "%.2f", vm.totalMiles),
                     unit:  "mi")
            Divider().frame(height: 32)
            statCell(value: String(format: "%.1f", vm.totalKm),
                     unit:  "km")
            Divider().frame(height: 32)
            statCell(value: String(format: "%.0f", vm.totalAscentFeet),
                     unit:  "ft gain")
            Divider().frame(height: 32)
            statCell(value: "\(vm.waypoints.count)",
                     unit:  "points")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private func statCell(value: String, unit: String) -> some View {
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
        VStack(spacing: 0) {

            // MARK: Out-and-back banner
            if vm.waypoints.count >= 2 {
                if vm.isOutAndBack {
                    // Active — show cancel
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "30D158"))
                        Text("OUT-AND-BACK ACTIVE")
                            .font(.system(size: 11, weight: .semibold,
                                          design: .monospaced))
                            .kerning(1)
                            .foregroundColor(Color(hex: "30D158"))
                        Spacer()
                        Button {
                            vm.cancelOutAndBack()
                        } label: {
                            Text("CANCEL")
                                .font(.system(size: 10, weight: .bold,
                                              design: .monospaced))
                                .kerning(1)
                                .foregroundColor(Color(hex: "FF453A"))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Color(hex: "FF453A").opacity(0.12)
                                )
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 11)
                    .background(Color(hex: "30D158").opacity(0.08))
                    .overlay(
                        Rectangle()
                            .frame(height: 0.5)
                            .foregroundColor(
                                Color(hex: "30D158").opacity(0.2)),
                        alignment: .top
                    )

                } else {
                    // Inactive — offer to apply
                    Button {
                        vm.applyOutAndBack()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 12, weight: .semibold))
                            Text("MAKE OUT-AND-BACK")
                                .font(.system(size: 11, weight: .semibold,
                                              design: .monospaced))
                                .kerning(1)
                            Spacer()
                            Text(String(format: "%.2f mi total",
                                        vm.totalMiles * 2))
                                .font(.system(size: 11,
                                              design: .monospaced))
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .foregroundColor(Color(hex: "0A84FF"))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 11)
                        .background(Color(hex: "0A84FF").opacity(0.08))
                        .overlay(
                            Rectangle()
                                .frame(height: 0.5)
                                .foregroundColor(
                                    Color(hex: "0A84FF").opacity(0.2)),
                            alignment: .top
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isRouting)
                }
            }

            // MARK: Main button row
            HStack(spacing: 12) {

                // Center on user
                circleButton(icon:  "location.fill",
                             color: Color(hex: "0A84FF")) {
                    vm.centerOnUser()
                }

                // Undo / cancel out-and-back
                circleButton(icon:     "arrow.uturn.backward",
                             color:    .primary,
                             disabled: !vm.canUndo) {
                    vm.undoLast()
                }

                // Clear
                circleButton(icon:     "trash",
                             color:    Color(hex: "FF453A"),
                             disabled: vm.waypoints.isEmpty) {
                    showClearAlert = true
                }

                Spacer()

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

                // Elevation button
                if vm.segments.count >= 1 {
                    Button {
                        showElevation = true
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "mountain.2.fill")
                                .font(.system(size: 14, weight: .medium))
                            Text("ELEV")
                                .font(.system(size: 8, weight: .bold,
                                              design: .monospaced))
                                .kerning(1)
                        }
                        .foregroundColor(Color(hex: "FF9F0A"))
                        .frame(width: 46, height: 46)
                        .background(Color(hex: "FF9F0A").opacity(0.10))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color(hex: "FF9F0A").opacity(0.25),
                                        lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                // GPX export button
                Button {
                    if let url = vm.buildGPX() {
                        shareURL = url
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .medium))
                        Text("GPX")
                            .font(.system(size: 8, weight: .bold,
                                          design: .monospaced))
                            .kerning(1)
                    }
                    .foregroundColor(vm.canExport ? .primary : .secondary)
                    .frame(width: 46, height: 46)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!vm.canExport)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Circle Button

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

    // MARK: - Location Search Sheet

    private var locationSearchSheet: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                VStack(spacing: 0) {

                    // Search bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 15))

                        TextField("Search city, suburb, address...",
                                  text: $searchQuery)
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .onSubmit {
                                Task { await runSearch() }
                            }
                            .onChange(of: searchQuery) { _ in
                                if searchQuery.count > 2 {
                                    Task { await runSearch() }
                                } else if searchQuery.isEmpty {
                                    searchResults = []
                                }
                            }

                        if !searchQuery.isEmpty {
                            Button {
                                searchQuery   = ""
                                searchResults = []
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 15))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                    Divider()

                    if isSearching {
                        VStack(spacing: 12) {
                            Spacer().frame(height: 40)
                            ProgressView()
                                .tint(Color(hex: "0A84FF"))
                            Text("Searching...")
                                .font(.system(size: 13,
                                              design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)

                    } else if searchResults.isEmpty
                                && !searchQuery.isEmpty
                                && !isSearching {
                        VStack(spacing: 12) {
                            Spacer().frame(height: 40)
                            Image(systemName: "mappin.slash")
                                .font(.system(size: 36,
                                              weight: .ultraLight))
                                .foregroundColor(.secondary)
                            Text("No results found")
                                .font(.system(size: 15, weight: .light,
                                              design: .serif))
                                .foregroundColor(.primary)
                            Text("Try a different search term.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)

                    } else if searchResults.isEmpty {
                        VStack(spacing: 12) {
                            Spacer().frame(height: 40)
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 36,
                                              weight: .ultraLight))
                                .foregroundColor(.secondary)
                            Text("Search for a location")
                                .font(.system(size: 15, weight: .light,
                                              design: .serif))
                                .foregroundColor(.primary)
                            Text("Type a city, suburb, or address\nto move the map there.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)

                    } else {
                        List(searchResults, id: \.self) { item in
                            Button {
                                moveMap(to: item)
                                showSearch    = false
                                searchQuery   = ""
                                searchResults = []
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(
                                                .secondarySystemBackground))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: mapItemIcon(item))
                                            .font(.system(size: 14,
                                                          weight: .medium))
                                            .foregroundColor(
                                                Color(hex: "0A84FF"))
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name ?? "Unknown")
                                            .font(.system(size: 14,
                                                          weight: .medium))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Text(formattedAddress(item))
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 11,
                                                      weight: .medium))
                                        .foregroundColor(
                                            Color(.tertiaryLabel))
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                        .listStyle(.plain)
                    }

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("SEARCH LOCATION")
                        .font(.system(size: 12, weight: .semibold,
                                      design: .monospaced))
                        .foregroundColor(.secondary)
                        .kerning(3)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showSearch    = false
                        searchQuery   = ""
                        searchResults = []
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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
                        ForEach(
                            Array(vm.waypoints.enumerated()),
                            id: \.element.id
                        ) { i, wp in
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
                                    Text(String(
                                        format: "%.5f, %.5f",
                                        wp.coordinate.latitude,
                                        wp.coordinate.longitude
                                    ))
                                    .font(.system(size: 10,
                                                  design: .monospaced))
                                    .foregroundColor(.secondary)
                                }

                                Spacer()

                                if i < vm.segments.count {
                                    Text(String(
                                        format: "+%.1f mi",
                                        vm.segments[i].distanceM / 1609.344
                                    ))
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

    // MARK: - Search Helpers

    private func runSearch() async {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
        else { return }

        isSearching   = true
        searchResults = []

        let request                  = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchQuery
        request.resultTypes          = [.address, .pointOfInterest]
        request.region               = vm.cameraRegion

        do {
            let response  = try await MKLocalSearch(request: request).start()
            searchResults = response.mapItems
        } catch {
            searchResults = []
        }

        isSearching = false
    }

    private func moveMap(to item: MKMapItem) {
        guard let coord = item.placemark.location?.coordinate
        else { return }
        vm.cameraRegion = MKCoordinateRegion(
            center:             coord,
            latitudinalMeters:  2000,
            longitudinalMeters: 2000
        )
        vm.shouldMoveCamera = true
    }

    private func formattedAddress(_ item: MKMapItem) -> String {
        let p = item.placemark
        var parts: [String] = []
        if let city    = p.locality            { parts.append(city)    }
        if let state   = p.administrativeArea  { parts.append(state)   }
        if let country = p.country             { parts.append(country) }
        return parts.isEmpty
            ? (p.title ?? "")
            : parts.joined(separator: ", ")
    }

    private func mapItemIcon(_ item: MKMapItem) -> String {
        switch item.pointOfInterestCategory {
        case .park:            return "leaf.fill"
        case .stadium:         return "sportscourt.fill"
        case .beach:           return "water.waves"
        case .hospital:        return "cross.fill"
        case .airport:         return "airplane"
        case .publicTransport: return "tram.fill"
        default:               return "mappin.circle.fill"
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(
        context: Context
    ) -> UIActivityViewController {
        UIActivityViewController(activityItems: items,
                                 applicationActivities: nil)
    }
    func updateUIViewController(
        _ vc: UIActivityViewController,
        context: Context
    ) {}
}
