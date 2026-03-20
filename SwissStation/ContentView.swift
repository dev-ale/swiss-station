import SwiftUI

struct ContentView: View {
    @ObservedObject var service: StationService
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            Divider()

            if isSearching {
                searchView
            } else {
                departuresView
            }
        }
        .frame(width: 320)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            if isSearching {
                TextField("Search station...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.headline)
                    .onChange(of: searchText) { _, newValue in
                        searchTask?.cancel()
                        searchTask = Task {
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            guard !Task.isCancelled else { return }
                            await service.searchStations(query: newValue)
                        }
                    }

                Button {
                    isSearching = false
                    searchText = ""
                    service.searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(service.stationName)
                        .font(.headline)
                    if service.isLoading {
                        Text("Updating...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let status = service.locationStatus {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    Task { await service.findNearestStation() }
                } label: {
                    Image(systemName: "location")
                }
                .buttonStyle(.plain)
                .help("Find nearest station")

                Button {
                    isSearching = true
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.plain)

                Button {
                    Task { await service.fetchDepartures(force: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
    }

    // MARK: - Search

    private var searchView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if service.searchResults.isEmpty && !searchText.isEmpty {
                    Text("No stations found")
                        .foregroundStyle(.secondary)
                        .padding(12)
                } else {
                    ForEach(service.searchResults, id: \.stableID) { station in
                        Button {
                            service.selectStation(station)
                            isSearching = false
                            searchText = ""
                        } label: {
                            HStack {
                                Image(systemName: "tram.fill")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                Text(station.name ?? "")
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(Color.primary.opacity(0.001))
                        .onHover { hovering in
                            if hovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }

                        Divider().padding(.leading, 44)
                    }
                }
            }
        }
        .frame(maxHeight: 300)
    }

    // MARK: - Departures

    private var departuresView: some View {
        Group {
            if let error = service.error {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
            } else if service.departures.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tram")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No departures")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(service.departures) { departure in
                            DepartureRow(departure: departure)
                            Divider().padding(.leading, 44)
                        }
                    }
                }
                .frame(maxHeight: 400)
            }

            Divider()
            footerView
        }
    }

    @State private var showSettings = false

    private var footerView: some View {
        VStack(spacing: 0) {
            if showSettings {
                settingsView
                Divider()
            }

            HStack {
                Button {
                    withAnimation { showSettings.toggle() }
                } label: {
                    Image(systemName: "gear")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Text("Refresh every \(Int(service.refreshInterval))s")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(10)
        }
    }

    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Show station name in menu bar", isOn: $service.showStationInMenuBar)
                .font(.caption)

            HStack {
                Text("Refresh")
                    .font(.caption)
                Spacer()
                Picker("", selection: $service.refreshInterval) {
                    Text("30s").tag(TimeInterval(30))
                    Text("45s").tag(TimeInterval(45))
                    Text("60s").tag(TimeInterval(60))
                    Text("120s").tag(TimeInterval(120))
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            HStack {
                Text("Transport")
                    .font(.caption)
                Spacer()
                HStack(spacing: 8) {
                    ForEach(StationService.allTransports, id: \.id) { transport in
                        Toggle(transport.label, isOn: Binding(
                            get: { service.enabledTransports.contains(transport.id) },
                            set: { enabled in
                                if enabled {
                                    service.enabledTransports.insert(transport.id)
                                } else if service.enabledTransports.count > 1 {
                                    service.enabledTransports.remove(transport.id)
                                }
                            }
                        ))
                        .toggleStyle(.checkbox)
                        .font(.caption)
                    }
                }
            }
        }
        .padding(12)
    }
}

// MARK: - Departure Row

struct DepartureRow: View {
    let departure: Departure

    var body: some View {
        HStack(spacing: 10) {
            lineLabel
            destinationInfo
            Spacer()
            timeInfo
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var lineLabel: some View {
        Text(departure.lineNumber)
            .font(.system(.caption, design: .rounded, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 22)
            .background(LineColors.color(for: departure.lineNumber, category: departure.category))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var destinationInfo: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(departure.to)
                .font(.system(.body, weight: .medium))
                .lineLimit(1)

            if let platform = departure.stop.platform, !platform.isEmpty {
                Text("Platform \(platform)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var timeInfo: some View {
        VStack(alignment: .trailing, spacing: 1) {
            let mins = departure.minutesUntilDeparture
            if mins == 0 {
                Text("now")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.green)
            } else {
                Text("\(mins)′")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(mins <= 2 ? .orange : .primary)
            }

            if departure.delay > 0 {
                Text("+\(departure.delay)")
                    .font(.caption2)
                    .foregroundStyle(.red)
            } else if let time = departure.departureTime {
                Text(time, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

}
