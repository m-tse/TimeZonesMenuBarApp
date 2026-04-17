import SwiftUI

struct WorldTimezone: Identifiable, Codable, Equatable {
    let identifier: String
    var label: String
    var backgroundColorHex: String?
    var id: String { identifier }

    var timeZone: TimeZone {
        TimeZone(identifier: identifier) ?? .current
    }

    var backgroundColor: Color? {
        guard let hex = backgroundColorHex else { return nil }
        return Color(hex: hex)
    }
}

extension Color {
    init?(hex: String) {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        guard let val = UInt64(s, radix: 16) else { return nil }
        switch s.count {
        case 6:
            let r = Double((val >> 16) & 0xff) / 255
            let g = Double((val >> 8) & 0xff) / 255
            let b = Double(val & 0xff) / 255
            self = Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
        case 8:
            let r = Double((val >> 24) & 0xff) / 255
            let g = Double((val >> 16) & 0xff) / 255
            let b = Double((val >> 8) & 0xff) / 255
            let a = Double(val & 0xff) / 255
            self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
        default:
            return nil
        }
    }

    func toHexString() -> String? {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let r = Int((c.redComponent * 255).rounded())
        let g = Int((c.greenComponent * 255).rounded())
        let b = Int((c.blueComponent * 255).rounded())
        let a = Int((c.alphaComponent * 255).rounded())
        return String(format: "#%02X%02X%02X%02X", r, g, b, a)
    }
}

class TimezoneStore: ObservableObject {
    @Published var timezones: [WorldTimezone] = []
    @Published var hourOffset: Double = 0
    @Published var referenceTimezoneId: String = TimeZone.current.identifier
    @Published var use24Hour: Bool = UserDefaults.standard.object(forKey: "timezones_use24Hour") as? Bool ?? true {
        didSet { UserDefaults.standard.set(use24Hour, forKey: "timezones_use24Hour") }
    }

    var referenceTimeZone: TimeZone {
        TimeZone(identifier: referenceTimezoneId) ?? .current
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: "timezones_timezones"),
           let saved = try? JSONDecoder().decode([WorldTimezone].self, from: data) {
            timezones = saved
        } else {
            timezones = Self.defaultTimezones
        }
        ensureLocalTimezone()
    }

    func ensureLocalTimezone() {
        let localId = TimeZone.current.identifier
        if !timezones.contains(where: { $0.identifier == localId }) {
            // Try to find a nice label from the common list
            let label: String
            if let match = AddTimezoneView.commonTimezones.first(where: { $0.0 == localId }) {
                label = match.1
            } else {
                label = localId.components(separatedBy: "/").last?.replacingOccurrences(of: "_", with: " ") ?? localId
            }
            timezones.append(WorldTimezone(identifier: localId, label: label))
            save()
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(timezones) {
            UserDefaults.standard.set(data, forKey: "timezones_timezones")
        }
    }

    func add(_ tz: WorldTimezone) {
        guard !timezones.contains(where: { $0.identifier == tz.identifier }) else { return }
        timezones.append(tz)
        save()
    }

    func remove(_ tz: WorldTimezone) {
        timezones.removeAll { $0.identifier == tz.identifier }
        save()
    }

    func rename(_ tz: WorldTimezone, to newLabel: String) {
        if let idx = timezones.firstIndex(where: { $0.identifier == tz.identifier }) {
            timezones[idx].label = newLabel
            save()
        }
    }

    func setBackgroundColor(_ tz: WorldTimezone, hex: String?) {
        if let idx = timezones.firstIndex(where: { $0.identifier == tz.identifier }) {
            timezones[idx].backgroundColorHex = hex
            save()
        }
    }

    func move(from source: IndexSet, to destination: Int) {
        timezones.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func sortedTimezones(for date: Date) -> [WorldTimezone] {
        timezones.sorted { a, b in
            a.timeZone.secondsFromGMT(for: date) < b.timeZone.secondsFromGMT(for: date)
        }
    }

    static let defaultTimezones: [WorldTimezone] = [
        WorldTimezone(identifier: "America/Los_Angeles", label: "Los Angeles, US"),
        WorldTimezone(identifier: "America/New_York", label: "New York, US"),
        WorldTimezone(identifier: "Europe/London", label: "London, UK"),
        WorldTimezone(identifier: "Asia/Tokyo", label: "Tokyo, Japan"),
        WorldTimezone(identifier: "Australia/Sydney", label: "Sydney, Australia"),
    ]
}
