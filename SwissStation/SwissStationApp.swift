import SwiftUI

@main
struct SwissStationApp: App {
    @StateObject private var service = StationService()

    var body: some Scene {
        MenuBarExtra {
            ContentView(service: service)
        } label: {
            HStack(spacing: 4) {
                if let next = service.nextDeparture {
                    if service.showStationInMenuBar {
                        Text(service.stationName)
                    }
                    Image(nsImage: LineColors.menuBarIcon(line: next.lineNumber, category: next.category))
                    let mins = next.minutesUntilDeparture
                    Text(mins == 0 ? "now" : "\(mins)′")
                } else {
                    Image(systemName: "tram")
                    if service.showStationInMenuBar {
                        Text(service.stationName)
                    }
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
