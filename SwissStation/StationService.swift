import Foundation
import CoreLocation

@MainActor
final class StationService: ObservableObject {
    @Published var departures: [Departure] = []
    @Published var stationName: String = "Basel, Birmannsgasse"
    @Published var isLoading = false
    @Published var error: String?
    @Published var searchResults: [Station] = []
    @Published var locationStatus: String?
    @Published var showStationInMenuBar: Bool {
        didSet { UserDefaults.standard.set(showStationInMenuBar, forKey: "showStationInMenuBar") }
    }
    @Published var refreshInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval")
            startAutoRefresh()
        }
    }
    @Published var enabledTransports: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(enabledTransports), forKey: "enabledTransports")
            Task { await fetchDepartures(force: true) }
        }
    }

    static let allTransports: [(id: String, label: String)] = [
        ("tram", "Tram"),
        ("bus", "Bus"),
        ("train", "Train"),
    ]

    private var refreshTimer: Timer?
    private var lastFetchTime: Date = .distantPast
    private let minFetchInterval: TimeInterval = 15
    private let locationManager = LocationManager()

    var nextDeparture: Departure? {
        departures.first
    }

    init() {
        self.showStationInMenuBar = UserDefaults.standard.object(forKey: "showStationInMenuBar") as? Bool ?? true
        let savedInterval = UserDefaults.standard.double(forKey: "refreshInterval")
        self.refreshInterval = savedInterval > 0 ? savedInterval : 60
        if let saved = UserDefaults.standard.array(forKey: "enabledTransports") as? [String] {
            self.enabledTransports = Set(saved)
        } else {
            self.enabledTransports = ["tram"]
        }
        let hasSaved = loadSavedStation()
        startAutoRefresh()
        Task {
            if !hasSaved {
                await findNearestStation()
            } else {
                await fetchDepartures()
            }
        }
    }

    func fetchDepartures(force: Bool = false) async {
        guard force || Date().timeIntervalSince(lastFetchTime) >= minFetchInterval else { return }

        var components = URLComponents(string: "https://transport.opendata.ch/v1/stationboard")!
        var queryItems = [
            URLQueryItem(name: "station", value: stationName),
            URLQueryItem(name: "limit", value: "20"),
        ]
        for transport in enabledTransports {
            queryItems.append(URLQueryItem(name: "transportations[]", value: transport))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            error = "Invalid station name"
            return
        }

        isLoading = true
        error = nil

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(StationboardResponse.self, from: data)
            lastFetchTime = Date()
            departures = response.stationboard
            if let name = response.station?.name {
                stationName = name
                saveStation()
            }
        } catch {
            print("Fetch error: \(error)")
            self.error = "Failed to load departures"
            departures = []
        }

        isLoading = false
    }

    func searchStations(query: String) async {
        guard query.count >= 2 else {
            searchResults = []
            return
        }

        var components = URLComponents(string: "https://transport.opendata.ch/v1/locations")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "type", value: "station"),
        ]

        guard let url = components.url else {
            searchResults = []
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(LocationResponse.self, from: data)
            searchResults = response.stations.filter { $0.id != nil && $0.name != nil }
        } catch {
            searchResults = []
        }
    }

    func selectStation(_ station: Station) {
        guard let name = station.name else { return }
        stationName = name
        searchResults = []
        saveStation()
        Task { await fetchDepartures(force: true) }
    }

    func findNearestStation() async {
        locationStatus = "Locating..."
        do {
            let location = try await locationManager.requestLocation()
            let lat = location.coordinate.latitude
            let lng = location.coordinate.longitude

            var components = URLComponents(string: "https://transport.opendata.ch/v1/locations")!
            components.queryItems = [
                URLQueryItem(name: "x", value: String(lat)),
                URLQueryItem(name: "y", value: String(lng)),
                URLQueryItem(name: "type", value: "station"),
            ]

            guard let url = components.url else {
                locationStatus = nil
                return
            }

            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(LocationResponse.self, from: data)
            let candidates = response.stations.filter { $0.id != nil && $0.name != nil }

            // Try each nearby station until we find one with departures for our transport types
            for candidate in candidates {
                guard let name = candidate.name else { continue }
                locationStatus = "Checking \(name)..."

                var sbComponents = URLComponents(string: "https://transport.opendata.ch/v1/stationboard")!
                var queryItems = [
                    URLQueryItem(name: "station", value: name),
                    URLQueryItem(name: "limit", value: "1"),
                ]
                for transport in enabledTransports {
                    queryItems.append(URLQueryItem(name: "transportations[]", value: transport))
                }
                sbComponents.queryItems = queryItems

                guard let sbUrl = sbComponents.url else { continue }

                if let (sbData, _) = try? await URLSession.shared.data(from: sbUrl),
                   let sbResponse = try? JSONDecoder().decode(StationboardResponse.self, from: sbData),
                   !sbResponse.stationboard.isEmpty {
                    stationName = sbResponse.station?.name ?? name
                    saveStation()
                    locationStatus = nil
                    departures = sbResponse.stationboard
                    // Fetch full list now
                    await fetchDepartures(force: true)
                    return
                }
            }

            locationStatus = "No nearby stations with departures"
        } catch let error as LocationError {
            locationStatus = error.errorDescription
        } catch {
            locationStatus = "Location failed"
            print("Location error: \(error)")
        }
    }

    func startAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.fetchDepartures()
            }
        }
    }

    private func saveStation() {
        UserDefaults.standard.set(stationName, forKey: "selectedStation")
    }

    @discardableResult
    private func loadSavedStation() -> Bool {
        if let saved = UserDefaults.standard.string(forKey: "selectedStation") {
            stationName = saved
            return true
        }
        return false
    }
}
