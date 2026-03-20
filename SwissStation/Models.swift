import Foundation

struct StationboardResponse: Codable {
    let station: Station?
    let stationboard: [Departure]
}

struct Station: Codable, Hashable {
    let id: String?
    let name: String?
    let score: Double?
    let coordinate: Coordinate?
    let distance: Double?
    let icon: String?

    var stableID: String {
        id ?? name ?? UUID().uuidString
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
    }

    static func == (lhs: Station, rhs: Station) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }
}

struct Coordinate: Codable {
    let type: String?
    let x: Double?
    let y: Double?
}

struct Departure: Codable, Identifiable {
    let name: String
    let category: String
    let subcategory: String?
    let categoryCode: Int?
    let number: String
    let `operator`: String?
    let to: String
    let stop: Stop
    let capacity1st: Int?
    let capacity2nd: Int?

    var id: String {
        "\(name)-\(to)-\(stop.departureTimestamp ?? 0)"
    }

    var lineNumber: String {
        number
    }

    var departureTime: Date? {
        guard let ts = stop.departureTimestamp else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(ts))
    }

    var actualDepartureTime: Date? {
        if let prognosis = stop.prognosis,
           let progDeparture = prognosis.departure {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: progDeparture)
        }
        return departureTime
    }

    var delay: Int {
        stop.delay ?? 0
    }

    var minutesUntilDeparture: Int {
        guard let departure = actualDepartureTime else { return 0 }
        return max(0, Int(departure.timeIntervalSinceNow / 60))
    }
}

struct Stop: Codable {
    let station: Station?
    let arrival: String?
    let arrivalTimestamp: Int?
    let departure: String?
    let departureTimestamp: Int?
    let delay: Int?
    let platform: String?
    let prognosis: Prognosis?
    let realtimeAvailability: String?
    let location: Station?
}

struct Prognosis: Codable {
    let platform: String?
    let arrival: String?
    let departure: String?
    let capacity1st: Int?
    let capacity2nd: Int?
}

struct LocationResponse: Codable {
    let stations: [Station]
}
