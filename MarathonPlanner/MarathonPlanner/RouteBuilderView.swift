import SwiftUI
import MapKit

struct RouteBuilderView: View {

    @EnvironmentObject var routeStore  : SavedRouteStore
    @StateObject private var vm        = RouteBuilderViewModel()
    @State private var shareURL        : URL? = nil
    @State private var showClearAlert  = false
    @State private var showElevation   = false
    @State private var showSearch      = false
    @State private var showSaveSheet   = false
    @State private var showLibrary     = false
    @State private var showLayerPicker = false
    @State private var searchQuery     = ""
    @State private var searchResults   : [MKMapItem] = []
    @State private var isSearching     = false
    @State private var mapLayer        : MapLayer   = .standard
    @State private var poiMode         : MapPOIMode = .runnerFocused
    @State private var useMetric       : Bool       = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {

                // MARK: Map
                RouteMapView(
                    vm:        vm,
                    mapLayer:  mapLayer,
                    poiMode:   poiMode,
                    useMetric: useMetric
                )
                .ignoresSafeArea()

                // MARK: Floating controls — right side
                VStack {
                    Spacer().frame(height: 100)
                    HStack {
                        Spacer()
                        MapControlsView(
                            vm:        vm,
                            mapLayer:  $mapLayer,
                            poiMode:   $poiMode,
                            showLayer: $showLayerPicker,
                            useMetric: $useMetric
                        )
                        .padding(.trailing, 12)
                    }
                    Spacer()
                }

                // MARK: Routing spinner
                if vm.isRouting {
                    VStack {
                        HStack(spacing: 10) {
                            ProgressView().tint(.white)
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

                // MARK: Layer picker overlay
                if showLayerPicker {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                showLayerPicker = false
                            }
                        }

                    VStack {
                        Spacer()
                        LayerPickerView(
                            selectedLayer: $mapLayer,
                            poiMode:       $poiMode,
                            isShowing:     $showLayerPicker
                        )
                        .transition(.move(edge: .bottom)
                                        .combined(with: .opacity))
                        .cornerRadius(20, corners: [.topLeft, .topRight])
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.35), value: showLayerPicker)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 14) {
                        Button { showSearch = true } label: {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.primary)
                        }
                        Button { showLibrary = true } label: {
                            Image(systemName: "folder")
                                .foregroundColor(.primary)
                        }
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("ROUTE BUILDER")
                        .font(.system(size: 12, weight: .semibold,
                                      design: .monospaced))
                        .foregroundColor(.secondary)
                        .kerning(3)
                }
            }
            .sheet(isPresented: $showSearch) {
                locationSearchSheet
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
            .sheet(isPresented: $showSaveSheet) {
                SaveRouteSheet(
                    segments:    vm.segments,
                    totalMiles:  vm.totalMiles,
                    ascentFeet:  vm.totalAscentFeet,
                    difficulty:  routeDifficulty,
                    mapLayer:    mapLayer,
                    isPresented: $showSaveSheet
                )
                .environmentObject(routeStore)
            }
            .sheet(isPresented: $showLibrary) {
                SavedRoutesLibraryView(onLoad: { saved in
                    loadSavedRoute(saved)
                })
                .environmentObject(routeStore)
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
            statCell(
                value: useMetric
                    ? String(format: "%.1f", vm.totalKm)
                    : String(format: "%.2f", vm.totalMiles),
                unit: useMetric ? "km" : "mi"
            )
            Divider().frame(height: 32)
            statCell(
                value: String(format: "%.0f", vm.totalAscentFeet),
                unit:  "ft gain"
            )
            Divider().frame(height: 32)
            statCell(
                value: estimatedTime,
                unit:  "est. time"
            )
            Divider().frame(height: 32)
            Button {
                withAnimation { useMetric.toggle() }
            } label: {
                VStack(spacing: 2) {
                    Text(useMetric ? "KM" : "MI")
                        .font(.system(size: 18, weight: .thin,
                                      design: .monospaced))
                        .foregroundColor(Color(hex: "0A84FF"))
                    Text("markers")
                        .font(.system(size: 9, weight: .medium,
                                      design: .monospaced))
                        .foregroundColor(.secondary)
                        .kerning(1)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var estimatedTime: String {
        let totalSeconds = vm.totalMiles * 9 * 60
        let h = Int(totalSeconds) / 3600
        let m = (Int(totalSeconds) % 3600) / 60
        if totalSeconds < 60 { return "—" }
        return h > 0
            ? String(format: "%d:%02d", h, m)
            : String(format: "%dm", m)
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
                            Text(String(format: "%.2f %@ total",
                                        useMetric
                                            ? vm.totalKm * 2
                                            : vm.totalMiles * 2,
                                        useMetric ? "km" : "mi"))
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
            HStack(spacing: 10) {

                // Undo
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

                // Save button
                if vm.canExport {
                    Button {
                        showSaveSheet = true
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 14, weight: .medium))
                            Text("SAVE")
                                .font(.system(size: 8, weight: .bold,
                                              design: .monospaced))
                                .kerning(1)
                        }
                        .foregroundColor(Color(hex: "30D158"))
                        .frame(width: 46, height: 46)
                        .background(Color(hex: "30D158").opacity(0.10))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color(hex: "30D158").opacity(0.25),
                                        lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

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
                            ProgressView().tint(Color(hex: "0A84FF"))
                            Text("Searching...")
                                .font(.system(size: 13,
                                              design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    } else if searchResults.isEmpty
                                && !searchQuery.isEmpty {
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
                            Text("Type a city, suburb, or address.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
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



    // MARK: - Difficulty

    private var routeDifficulty: String {
        guard vm.totalMiles > 0 else { return "Flat" }
        let gainPer100m = (vm.totalAscentFeet / 3.28084)
            / (vm.totalMiles * 1609.344 / 100)
        switch gainPer100m {
        case ..<8:    return "Flat"
        case 8..<15:  return "Rolling"
        case 15..<25: return "Hilly"
        default:      return "Very Hilly"
        }
    }

    // MARK: - Load Saved Route

    private func loadSavedRoute(_ saved: SavedRoute) {
        vm.clearAll()

        let coords = saved.coordinateData.map { $0.coordinate }
        guard coords.count >= 2 else { return }

        let polyline = MKPolyline(coordinates: coords, count: coords.count)
        let segment  = RouteSegment(
            polyline:  polyline,
            distanceM: saved.distanceMeters,
            ascentM:   saved.ascentMeters
        )
        vm.segments  = [segment]
        vm.waypoints = [
            RouteWaypoint(coordinate: coords.first!, index: 0),
            RouteWaypoint(coordinate: coords.last!,  index: 1)
        ]

        let region = MKCoordinateRegion(
            polyline.boundingMapRect
        ).paddedBy(1.3)
        vm.cameraRegion     = region
        vm.shouldMoveCamera = true
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
        vm.cameraRegion     = MKCoordinateRegion(
            center:             coord,
            latitudinalMeters:  2000,
            longitudinalMeters: 2000
        )
        vm.shouldMoveCamera = true
    }

    private func formattedAddress(_ item: MKMapItem) -> String {
        let p = item.placemark
        var parts: [String] = []
        if let city    = p.locality           { parts.append(city)    }
        if let state   = p.administrativeArea { parts.append(state)   }
        if let country = p.country            { parts.append(country) }
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

// MARK: - Corner Radius Helper

extension View {
    func cornerRadius(_ radius: CGFloat,
                      corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius  : CGFloat      = .infinity
    var corners : UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect:       rect,
            byRoundingCorners: corners,
            cornerRadii:       CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - MKCoordinateRegion Extension

extension MKCoordinateRegion {
    init(_ mapRect: MKMapRect) {
        let sw = MKMapPoint(x: mapRect.minX, y: mapRect.maxY)
        let ne = MKMapPoint(x: mapRect.maxX, y: mapRect.minY)
        self.init(
            center: CLLocationCoordinate2D(
                latitude:  (sw.coordinate.latitude
                            + ne.coordinate.latitude) / 2,
                longitude: (sw.coordinate.longitude
                            + ne.coordinate.longitude) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta:  abs(ne.coordinate.latitude
                                    - sw.coordinate.latitude),
                longitudeDelta: abs(ne.coordinate.longitude
                                    - sw.coordinate.longitude)
            )
        )
    }

    func paddedBy(_ factor: Double) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta:  span.latitudeDelta  * factor,
                longitudeDelta: span.longitudeDelta * factor
            )
        )
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
