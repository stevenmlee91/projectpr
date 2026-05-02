import SwiftUI
import MapKit

// MARK: - Save Route Sheet

struct SaveRouteSheet: View {
    let segments      : [RouteSegment]
    let totalMiles    : Double
    let ascentFeet    : Double
    let difficulty    : String
    let mapLayer      : MapLayer
    @Binding var isPresented: Bool

    @EnvironmentObject var routeStore: SavedRouteStore

    @State private var routeName      = ""
    @State private var isSaving       = false
    @State private var thumbnailImage : UIImage? = nil
    @State private var isGenerating   = true
    @FocusState private var nameFieldFocused: Bool

    private var isValid: Bool {
        !routeName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        // MARK: Thumbnail preview
                        thumbnailSection

                        // MARK: Name field
                        nameSection

                        // MARK: Stats preview
                        statsSection

                        // MARK: Save button
                        saveButton

                        Spacer().frame(height: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("SAVE ROUTE")
                        .font(.system(size: 12, weight: .semibold,
                                      design: .monospaced))
                        .foregroundColor(.secondary)
                        .kerning(3)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { isPresented = false }
                        .foregroundColor(.primary)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task { await generateThumbnail() }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                nameFieldFocused = true
            }
        }
    }

    // MARK: - Thumbnail Section

    private var thumbnailSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .frame(height: 180)

            if isGenerating {
                VStack(spacing: 10) {
                    ProgressView().tint(Color(hex: "0A84FF"))
                    Text("Generating preview...")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            } else if let img = thumbnailImage {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(.system(size: 32, weight: .ultraLight))
                        .foregroundColor(.secondary)
                    Text("Preview unavailable")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Name Section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ROUTE NAME")
                .font(.system(size: 10, weight: .semibold,
                              design: .monospaced))
                .foregroundColor(.secondary)
                .kerning(3)

            ZStack {
                Color(.secondarySystemBackground)
                HStack {
                    TextField(namePlaceholder, text: $routeName)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .focused($nameFieldFocused)
                        .submitLabel(.done)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                    if !routeName.isEmpty {
                        Button {
                            routeName = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .padding(.trailing, 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .cornerRadius(12)
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: 0) {
            statCell(
                label: "DISTANCE",
                value: String(format: "%.2f mi", totalMiles),
                icon:  "arrow.left.and.right"
            )
            Divider().frame(height: 44)
            statCell(
                label: "GAIN",
                value: String(format: "%.0f ft", ascentFeet),
                icon:  "arrow.up"
            )
            Divider().frame(height: 44)
            statCell(
                label: "DIFFICULTY",
                value: difficulty,
                icon:  "mountain.2.fill",
                color: difficultyColor
            )
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func statCell(label: String, value: String,
                           icon: String,
                           color: Color = .primary) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 13, weight: .semibold,
                              design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 8, weight: .semibold,
                              design: .monospaced))
                .foregroundColor(.secondary)
                .kerning(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            Task { await saveRoute() }
        } label: {
            HStack(spacing: 10) {
                if isSaving {
                    ProgressView().tint(Color(.systemBackground))
                        .scaleEffect(0.8)
                    Text("SAVING...")
                        .font(.system(size: 13, weight: .semibold,
                                      design: .monospaced))
                        .kerning(1)
                } else {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 14, weight: .medium))
                    Text("SAVE ROUTE")
                        .font(.system(size: 13, weight: .semibold,
                                      design: .monospaced))
                        .kerning(1)
                }
            }
            .foregroundColor(Color(.systemBackground))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(isValid
                        ? Color(.label)
                        : Color(.systemFill))
            .cornerRadius(14)
        }
        .disabled(!isValid || isSaving)
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var namePlaceholder: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let day = formatter.string(from: Date())
        switch totalMiles {
        case ..<5:   return "\(day) Easy Run"
        case ..<10:  return "\(day) Tempo Loop"
        case ..<16:  return "\(day) Medium Long"
        default:     return "\(day) Long Run"
        }
    }

    private var difficultyColor: Color {
        switch difficulty {
        case "Flat":       return Color(hex: "30D158")
        case "Rolling":    return Color(hex: "FFD60A")
        case "Hilly":      return Color(hex: "FF9F0A")
        case "Very Hilly": return Color(hex: "FF453A")
        default:           return Color(hex: "30D158")
        }
    }

    private func generateThumbnail() async {
        isGenerating   = true
        let data       = await RouteSnapshotGenerator.generate(
            segments:  segments,
            mapLayer:  mapLayer
        )
        if let d = data { thumbnailImage = UIImage(data: d) }
        isGenerating   = false
    }

    private func saveRoute() async {
        isSaving = true

        // Generate thumbnail if not already done
        var thumbData: Data? = thumbnailImage?.pngData()
        if thumbData == nil {
            thumbData = await RouteSnapshotGenerator.generate(
                segments: segments,
                mapLayer: mapLayer
            )
        }

        // Extract all coordinates from segments
        var allCoords: [RouteCoordinateData] = []
        for segment in segments {
            let count  = segment.polyline.pointCount
            var coords = [CLLocationCoordinate2D](
                repeating: kCLLocationCoordinate2DInvalid,
                count: count
            )
            segment.polyline.getCoordinates(
                &coords,
                range: NSRange(location: 0, length: count)
            )
            allCoords.append(contentsOf:
                coords
                    .filter { CLLocationCoordinate2DIsValid($0) }
                    .map    { RouteCoordinateData($0) }
            )
        }

        let totalMeters = segments.reduce(0) { $0 + $1.distanceM }
        let ascentM     = segments.reduce(0) { $0 + $1.ascentM }

        let route = SavedRoute(
            name:           routeName.trimmingCharacters(in: .whitespaces),
            distanceMeters: totalMeters,
            ascentMeters:   ascentM,
            difficulty:     difficulty,
            coordinateData: allCoords,
            thumbnailData:  thumbData
        )

        routeStore.save(route)
        isSaving     = false
        isPresented  = false
    }
}
