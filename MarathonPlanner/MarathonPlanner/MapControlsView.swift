import SwiftUI
import MapKit

// MARK: - Floating Map Controls

struct MapControlsView: View {
    @ObservedObject var vm    : RouteBuilderViewModel
    @Binding var mapLayer     : MapLayer
    @Binding var poiMode      : MapPOIMode
    @Binding var showLayer    : Bool
    @Binding var useMetric    : Bool

    var body: some View {
        VStack(spacing: 10) {

            // Layer picker button
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showLayer.toggle()
                }
            } label: {
                floatingIcon(
                    icon:  mapLayer.icon,
                    color: showLayer ? Color(hex: "0A84FF") : .primary,
                    bg:    showLayer
                        ? Color(hex: "0A84FF").opacity(0.15)
                        : Color(.secondarySystemBackground)
                )
            }
            .buttonStyle(.plain)

            // Center on user
            Button { vm.centerOnUser() } label: {
                floatingIcon(icon: "location.fill",
                             color: Color(hex: "0A84FF"))
            }
            .buttonStyle(.plain)

            // Fit route in view
            if !vm.segments.isEmpty {
                Button { fitRoute() } label: {
                    floatingIcon(icon: "arrow.up.left.and.arrow.down.right",
                                 color: .primary)
                }
                .buttonStyle(.plain)
            }

            // Units toggle
            Button {
                withAnimation { useMetric.toggle() }
            } label: {
                floatingIcon(
                    label: useMetric ? "KM" : "MI",
                    color: .primary
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Fit route

    private func fitRoute() {
        guard !vm.segments.isEmpty else { return }

        var minLat =  90.0, maxLat = -90.0
        var minLon = 180.0, maxLon = -180.0

        for segment in vm.segments {
            let count  = segment.polyline.pointCount
            var coords = [CLLocationCoordinate2D](
                repeating: kCLLocationCoordinate2DInvalid,
                count: count
            )
            segment.polyline.getCoordinates(
                &coords,
                range: NSRange(location: 0, length: count)
            )
            for c in coords {
                minLat = min(minLat, c.latitude)
                maxLat = max(maxLat, c.latitude)
                minLon = min(minLon, c.longitude)
                maxLon = max(maxLon, c.longitude)
            }
        }

        let center = CLLocationCoordinate2D(
            latitude:  (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta:  (maxLat - minLat) * 1.4,
            longitudeDelta: (maxLon - minLon) * 1.4
        )
        vm.cameraRegion    = MKCoordinateRegion(center: center, span: span)
        vm.shouldMoveCamera = true
    }

    // MARK: - Icon builders

    private func floatingIcon(icon: String,
                               color: Color,
                               bg: Color = Color(
                                   .secondarySystemBackground)
    ) -> some View {
        Image(systemName: icon)
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(color)
            .frame(width: 44, height: 44)
            .background(bg)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
    }

    private func floatingIcon(label: String,
                               color: Color) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(color)
            .frame(width: 44, height: 44)
            .background(Color(.secondarySystemBackground))
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
    }
}

// MARK: - Layer Picker Sheet

struct LayerPickerView: View {
    @Binding var selectedLayer : MapLayer
    @Binding var poiMode       : MapPOIMode
    @Binding var isShowing     : Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Handle
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 16)

            Text("MAP STYLE")
                .font(.system(size: 10, weight: .semibold,
                              design: .monospaced))
                .foregroundColor(.secondary)
                .kerning(3)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            // Layer grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                ForEach(MapLayer.allCases) { layer in
                    layerCard(layer)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)

            Divider()
                .padding(.bottom, 16)

            Text("POINTS OF INTEREST")
                .font(.system(size: 10, weight: .semibold,
                              design: .monospaced))
                .foregroundColor(.secondary)
                .kerning(3)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            // POI mode row
            HStack(spacing: 8) {
                ForEach(MapPOIMode.allCases) { mode in
                    poiChip(mode)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
    }

    // MARK: Layer Card

    private func layerCard(_ layer: MapLayer) -> some View {
        let isSelected = selectedLayer == layer
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedLayer = layer
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(layerCardColor(layer))
                        .frame(height: 52)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    isSelected
                                        ? Color(hex: "0A84FF")
                                        : Color.clear,
                                    lineWidth: 2
                                )
                        )
                    Image(systemName: layer.icon)
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(layerIconColor(layer))
                }

                Text(layer.label)
                    .font(.system(size: 10, weight: isSelected
                                  ? .semibold : .regular,
                                  design: .monospaced))
                    .foregroundColor(isSelected
                                     ? Color(hex: "0A84FF")
                                     : .secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    private func layerCardColor(_ layer: MapLayer) -> Color {
        switch layer {
        case .standard:  return Color(.secondarySystemBackground)
        case .muted:     return Color(.systemGray5)
        case .satellite: return Color(hex: "1A3A2A")
        case .hybrid:    return Color(hex: "1A2A3A")
        case .dark:      return Color(hex: "1A1A1A")
        }
    }

    private func layerIconColor(_ layer: MapLayer) -> Color {
        switch layer {
        case .standard:  return .primary
        case .muted:     return .secondary
        case .satellite: return Color(hex: "30D158")
        case .hybrid:    return Color(hex: "0A84FF")
        case .dark:      return Color(hex: "FF9F0A")
        }
    }

    // MARK: POI Chip

    private func poiChip(_ mode: MapPOIMode) -> some View {
        let isSelected = poiMode == mode
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                poiMode = mode
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: mode.icon)
                    .font(.system(size: 11, weight: .medium))
                Text(mode.rawValue)
                    .font(.system(size: 11, weight: isSelected
                                  ? .semibold : .regular,
                                  design: .monospaced))
            }
            .foregroundColor(isSelected
                             ? Color(.systemBackground)
                             : .primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected
                        ? Color(.label)
                        : Color(.secondarySystemBackground))
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}
