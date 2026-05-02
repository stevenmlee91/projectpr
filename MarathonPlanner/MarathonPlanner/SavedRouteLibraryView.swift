import SwiftUI
import MapKit

// MARK: - Saved Routes Library

struct SavedRoutesLibraryView: View {
    @EnvironmentObject var routeStore : SavedRouteStore
    @Environment(\.dismiss) var dismiss

    var onLoad: ((SavedRoute) -> Void)?

    @State private var routeToRename  : SavedRoute? = nil
    @State private var routeToDelete  : SavedRoute? = nil
    @State private var newName        = ""
    @State private var searchQuery    = ""

    private var filteredRoutes: [SavedRoute] {
        if searchQuery.isEmpty { return routeStore.routes }
        return routeStore.routes.filter {
            $0.name.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                if routeStore.routes.isEmpty {
                    emptyState
                } else {
                    routeList
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("SAVED ROUTES")
                        .font(.system(size: 12, weight: .semibold,
                                      design: .monospaced))
                        .foregroundColor(.secondary)
                        .kerning(3)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.primary)
                }
            }
            .alert("Rename Route", isPresented: .init(
                get: { routeToRename != nil },
                set: { if !$0 { routeToRename = nil } }
            )) {
                TextField("Route name", text: $newName)
                Button("Save") {
                    if let r = routeToRename {
                        routeStore.rename(r, to: newName)
                    }
                    routeToRename = nil
                }
                Button("Cancel", role: .cancel) {
                    routeToRename = nil
                }
            }
            .alert("Delete Route", isPresented: .init(
                get: { routeToDelete != nil },
                set: { if !$0 { routeToDelete = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let r = routeToDelete {
                        routeStore.delete(r)
                    }
                    routeToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    routeToDelete = nil
                }
            } message: {
                if let r = routeToDelete {
                    Text("Delete \"\(r.name)\"? This cannot be undone.")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Route List

    private var routeList: some View {
        ScrollView {
            VStack(spacing: 0) {

                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                    TextField("Search routes...", text: $searchQuery)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .autocorrectionDisabled()
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(11)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)

                // Route count
                HStack {
                    Text("\(filteredRoutes.count) ROUTE\(filteredRoutes.count == 1 ? "" : "S")")
                        .font(.system(size: 10, weight: .semibold,
                                      design: .monospaced))
                        .foregroundColor(.secondary)
                        .kerning(2)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

                if filteredRoutes.isEmpty {
                    VStack(spacing: 12) {
                        Spacer().frame(height: 40)
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32, weight: .ultraLight))
                            .foregroundColor(.secondary)
                        Text("No routes match \"\(searchQuery)\"")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredRoutes) { route in
                            RouteCardView(
                                route: route,
                                onLoad: {
                                    onLoad?(route)
                                    dismiss()
                                },
                                onFavorite: {
                                    routeStore.toggleFavorite(route)
                                },
                                onRename: {
                                    newName       = route.name
                                    routeToRename = route
                                },
                                onDuplicate: {
                                    routeStore.duplicate(route)
                                },
                                onDelete: {
                                    routeToDelete = route
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "map")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundColor(Color(.tertiarySystemBackground))
            VStack(spacing: 8) {
                Text("No Saved Routes")
                    .font(.system(size: 20, weight: .light, design: .serif))
                    .foregroundColor(.primary)
                Text("Build a route and tap Save\nto add it to your library.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
    }
}

// MARK: - Route Card View

struct RouteCardView: View {
    let route       : SavedRoute
    let onLoad      : () -> Void
    let onFavorite  : () -> Void
    let onRename    : () -> Void
    let onDuplicate : () -> Void
    let onDelete    : () -> Void

    @State private var showActions = false

    var body: some View {
        Button(action: onLoad) {
            VStack(spacing: 0) {

                // MARK: Thumbnail
                ZStack(alignment: .topTrailing) {
                    if let img = route.thumbnail {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 140)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color(.secondarySystemBackground))
                            .frame(height: 140)
                            .overlay(
                                Image(systemName: "map")
                                    .font(.system(size: 28,
                                                  weight: .ultraLight))
                                    .foregroundColor(.secondary)
                            )
                    }

                    // Favorite star
                    if route.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.yellow)
                            .padding(10)
                            .background(
                                Color.black.opacity(0.4)
                                    .clipShape(Circle())
                            )
                            .padding(10)
                    }
                }

                // MARK: Info
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(route.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Text(route.formattedDate)
                                .font(.system(size: 11,
                                              design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        // Difficulty badge
                        Text(route.difficulty)
                            .font(.system(size: 9, weight: .bold,
                                          design: .monospaced))
                            .kerning(1)
                            .foregroundColor(route.difficultyColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                route.difficultyColor.opacity(0.12)
                            )
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(route.difficultyColor.opacity(0.3),
                                            lineWidth: 1)
                            )
                    }

                    // Stats row
                    HStack(spacing: 16) {
                        routeStat(
                            icon:  "arrow.left.and.right",
                            value: String(format: "%.2f mi",
                                          route.distanceMiles)
                        )
                        routeStat(
                            icon:  "arrow.up",
                            value: String(format: "%.0f ft gain",
                                          route.ascentFeet)
                        )
                        Spacer()

                        // Action menu
                        Menu {
                            Button {
                                onLoad()
                            } label: {
                                Label("Load Route", systemImage: "map")
                            }
                            Button {
                                onFavorite()
                            } label: {
                                Label(route.isFavorite
                                      ? "Remove Favorite"
                                      : "Add to Favorites",
                                      systemImage: route.isFavorite
                                          ? "star.slash"
                                          : "star")
                            }
                            Button {
                                onRename()
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            Button {
                                onDuplicate()
                            } label: {
                                Label("Duplicate",
                                      systemImage: "plus.square.on.square")
                            }
                            Divider()
                            Button(role: .destructive) {
                                onDelete()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
                .background(Color(.secondarySystemBackground))
            }
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }

    private func routeStat(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
}
