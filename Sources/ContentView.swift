import SwiftUI
import ServiceManagement

struct ContentView: View {
    @EnvironmentObject var store: TimezoneStore
    @State private var now = Date()
    @State private var showingAdd = false
    @State private var showingSettings = false
    @State private var panelHeight: CGFloat = {
        let saved = UserDefaults.standard.double(forKey: "timezones_panelHeight")
        return CGFloat(saved > 0 ? saved : 500).clamped(min: 300, max: 900)
    }()
    @State private var isDragging = false
    @State private var renamingTimezone: WorldTimezone? = nil
    @State private var renameText = ""
    @State private var colorPickingTimezone: WorldTimezone? = nil
    @State private var pickerColor: Color = .white
    @State private var pickingReferenceHighlight = false
    @State private var showingDatePicker = false
    @State private var keyMonitor: Any?
    @State private var pickerDate = Date()
    @State private var pickerTimeZone = TimeZone.current

    let timer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    var selectedDate: Date {
        now.addingTimeInterval(store.hourOffset * 3600)
    }

    var body: some View {
        VStack(spacing: 0) {
            if showingSettings {
                settingsView
            } else if showingAdd {
                AddTimezoneView(isShowing: $showingAdd)
                    .environmentObject(store)
            } else if showingDatePicker {
                datePickerView
            } else if let tz = renamingTimezone {
                renameView(for: tz)
            } else if let tz = colorPickingTimezone {
                colorPickerView(for: tz)
            } else if pickingReferenceHighlight {
                referenceHighlightPickerView
            } else {
                mainView
            }
        }
        .frame(width: 360, height: panelHeight)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.4))
        .onReceive(timer) { _ in
            now = Date()
        }
        .onAppear {
            now = Date()
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 { // escape
                    (event.window ?? NSApp.keyWindow)?.orderOut(nil)
                    return nil
                }
                guard !showingAdd && !showingSettings && !showingDatePicker && renamingTimezone == nil && colorPickingTimezone == nil && !pickingReferenceHighlight else {
                    return event
                }
                let modifiers = event.modifierFlags.intersection([.command, .control, .option])
                if modifiers.isEmpty,
                   event.charactersIgnoringModifiers?.lowercased() == "r" {
                    withAnimation(.easeOut(duration: 0.3)) {
                        store.hourOffset = 0
                    }
                    return nil
                }
                let step = event.modifierFlags.contains(.shift) ? 1.0 : 1.0 / 60.0
                switch event.keyCode {
                case 123: // left arrow
                    store.hourOffset -= step
                    return nil
                case 124: // right arrow
                    store.hourOffset += step
                    return nil
                case 126: // up arrow
                    selectAdjacentTimezone(offset: -1)
                    return nil
                case 125: // down arrow
                    selectAdjacentTimezone(offset: 1)
                    return nil
                default:
                    return event
                }
            }
        }
        .onDisappear {
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
                keyMonitor = nil
            }
        }
    }

    static let presetColors: [(name: String, hex: String)] = [
        ("Red",    "#FFB3B3B3"),
        ("Orange", "#FFD29EB3"),
        ("Yellow", "#FFF6C9B3"),
        ("Green",  "#B8E3B8B3"),
        ("Teal",   "#B3E0E0B3"),
        ("Blue",   "#B3CCFFB3"),
        ("Purple", "#D9B3FFB3"),
        ("Pink",   "#FFCCE6B3"),
        ("Gray",   "#D9D9D9B3"),
    ]

    @ViewBuilder
    func colorPickerView(for tz: WorldTimezone) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    colorPickingTimezone = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.caption)
                }
                .buttonStyle(.borderless)
                Spacer()
                Text("Background Color")
                    .font(.headline)
                Spacer()
                Text("Back  ")
                    .font(.caption)
                    .hidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Text(tz.label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .padding(.bottom, 12)

            ColorPicker("Pick a color", selection: $pickerColor, supportsOpacity: true)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .onChange(of: pickerColor) { newColor in
                    if let hex = newColor.toHexString() {
                        store.setBackgroundColor(tz, hex: hex)
                    }
                }

            HStack {
                Button("Clear") {
                    store.setBackgroundColor(tz, hex: nil)
                    colorPickingTimezone = nil
                }
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)

                Spacer()

                Button("Done") {
                    colorPickingTimezone = nil
                }
                .buttonStyle(.borderless)
            }
            .font(.system(size: 12))
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Spacer()
        }
    }

    @ViewBuilder
    var referenceHighlightPickerView: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    pickingReferenceHighlight = false
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.caption)
                }
                .buttonStyle(.borderless)
                Spacer()
                Text("Reference Highlight")
                    .font(.headline)
                Spacer()
                Text("Back  ")
                    .font(.caption)
                    .hidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            ColorPicker("Pick a color", selection: $pickerColor, supportsOpacity: true)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .onChange(of: pickerColor) { newColor in
                    if let hex = newColor.toHexString() {
                        store.referenceHighlightHex = hex
                    }
                }

            HStack {
                Button("Reset to default") {
                    store.referenceHighlightHex = nil
                    pickingReferenceHighlight = false
                }
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)

                Spacer()

                Button("Done") {
                    pickingReferenceHighlight = false
                }
                .buttonStyle(.borderless)
            }
            .font(.system(size: 12))
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Spacer()
        }
    }

    @ViewBuilder
    func renameView(for tz: WorldTimezone) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    renamingTimezone = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.caption)
                }
                .buttonStyle(.borderless)
                Spacer()
                Text("Rename")
                    .font(.headline)
                Spacer()
                Text("Back  ")
                    .font(.caption)
                    .hidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            TextField("City name", text: $renameText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .onSubmit {
                    if !renameText.isEmpty {
                        store.rename(tz, to: renameText)
                    }
                    renamingTimezone = nil
                }

            HStack {
                Button("Cancel") {
                    renamingTimezone = nil
                }
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)

                Spacer()

                Button("Save") {
                    if !renameText.isEmpty {
                        store.rename(tz, to: renameText)
                    }
                    renamingTimezone = nil
                }
                .buttonStyle(.borderless)
            }
            .font(.system(size: 12))
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Spacer()
        }
    }

    @ViewBuilder
    var settingsView: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    showingSettings = false
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.caption)
                }
                .buttonStyle(.borderless)
                Spacer()
                Text("Settings")
                    .font(.headline)
                Spacer()
                Text("Back  ")
                    .font(.caption)
                    .hidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            VStack(spacing: 12) {
                Toggle("24-hour time", isOn: $store.use24Hour)
                    .toggleStyle(.switch)

                Toggle("Launch on login", isOn: Binding(
                    get: { SMAppService.mainApp.status == .enabled },
                    set: { newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            // silently ignore
                        }
                    }
                ))
                .toggleStyle(.switch)
            }
            .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 6) {
                Text("Tips")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("\u{2022} Right-click on time zones to rename, recolor, or remove them")
                Text("\u{2022} Use \u{2190} \u{2192} arrow keys to move the slider by one minute")
                Text("\u{2022} Hold Shift + \u{2190} \u{2192} to move by one hour")
                Text("\u{2022} Use \u{2191} \u{2193} arrow keys to select the previous or next timezone")
                Text("\u{2022} Press R to reset the time to now")
                Text("\u{2022} Double-click the slider to return to the current time")
                Text("\u{2022} Click the date to open a calendar picker")
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Spacer()
        }
    }

    @ViewBuilder
    var datePickerView: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    showingDatePicker = false
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.caption)
                }
                .buttonStyle(.borderless)
                Spacer()
                Text("Jump to Date")
                    .font(.headline)
                Spacer()
                Text("Back  ")
                    .font(.caption)
                    .hidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            DatePicker("", selection: $pickerDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .environment(\.timeZone, pickerTimeZone)
                .padding(.horizontal, 16)
                .onChange(of: pickerDate) { newDate in
                    let now = Date()
                    var refCal = Calendar.current
                    refCal.timeZone = pickerTimeZone
                    // Picker returns date in reference tz; extract the date it shows
                    let pickedComps = refCal.dateComponents([.year, .month, .day], from: newDate)
                    // Preserve current time-of-day in the reference timezone
                    let timeComps = refCal.dateComponents([.hour, .minute, .second], from: selectedDate)
                    var target = DateComponents()
                    target.year = pickedComps.year
                    target.month = pickedComps.month
                    target.day = pickedComps.day
                    target.hour = timeComps.hour
                    target.minute = timeComps.minute
                    target.second = timeComps.second
                    if let targetDate = refCal.date(from: target) {
                        let diff = targetDate.timeIntervalSince(now) / 3600.0
                        store.hourOffset = (diff * 60).rounded() / 60
                    }
                }

            HStack {
                Button("Today") {
                    store.hourOffset = 0
                    showingDatePicker = false
                }
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)

                Spacer()

                Button("Done") {
                    showingDatePicker = false
                }
                .buttonStyle(.borderless)
            }
            .font(.system(size: 12))
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Spacer()
        }
    }

    @ViewBuilder
    var mainView: some View {
        // Timezone list
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(store.sortedTimezones(for: selectedDate)) { tz in
                    let isReference = tz.identifier == store.referenceTimezoneId
                    TimezoneRowView(
                        timezone: tz,
                        selectedDate: selectedDate,
                        localTimeZone: store.referenceTimeZone,
                        hourOffset: $store.hourOffset,
                        isHighlighted: isReference,
                        highlightColor: store.referenceHighlightColor,
                        use24Hour: store.use24Hour,
                        onDateTap: {
                            pickerTimeZone = tz.timeZone
                            pickerDate = selectedDate
                            showingDatePicker = true
                        }
                    )
                    .onTapGesture {
                        store.referenceTimezoneId = tz.identifier
                    }
                    .contextMenu {
                        if !isReference {
                            Button("Set as reference") {
                                store.referenceTimezoneId = tz.identifier
                            }
                        }
                        Button("Rename…") {
                            renameText = tz.label
                            renamingTimezone = tz
                        }
                        Menu("Background color") {
                            ForEach(Self.presetColors, id: \.name) { preset in
                                Button(preset.name) {
                                    store.setBackgroundColor(tz, hex: preset.hex)
                                }
                            }
                            Divider()
                            Button("Custom…") {
                                pickerColor = tz.backgroundColor ?? .white
                                colorPickingTimezone = tz
                            }
                            if tz.backgroundColorHex != nil {
                                Divider()
                                Button("Clear color") {
                                    store.setBackgroundColor(tz, hex: nil)
                                }
                            }
                        }
                        if isReference {
                            Menu("Reference highlight color") {
                                ForEach(Self.presetColors, id: \.name) { preset in
                                    Button(preset.name) {
                                        store.referenceHighlightHex = preset.hex
                                    }
                                }
                                Divider()
                                Button("Custom…") {
                                    pickerColor = store.referenceHighlightColor
                                    pickingReferenceHighlight = true
                                }
                                if store.referenceHighlightHex != nil {
                                    Divider()
                                    Button("Reset to default") {
                                        store.referenceHighlightHex = nil
                                    }
                                }
                            }
                        }
                        if tz.timeZone.identifier != TimeZone.current.identifier {
                            Button("Remove") { store.remove(tz) }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }

        Divider()

        // Footer
        VStack(spacing: 6) {
            Button {
                withAnimation(.easeOut(duration: 0.3)) {
                    store.hourOffset = 0
                }
            } label: {
                Text("Reset")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(store.hourOffset != 0 ? .white : .secondary.opacity(0.35))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(ResetButtonStyle(isActive: store.hourOffset != 0))
            .disabled(store.hourOffset == 0)

            HStack {
                Button { showingAdd = true } label: {
                    Label("Add", systemImage: "plus")
                        .labelStyle(TightLabelStyle())
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(HoverHighlightStyle())
                Spacer()
                Button {
                    showingSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                        .labelStyle(TightLabelStyle())
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(HoverHighlightStyle())
                Spacer()
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                        .labelStyle(TightLabelStyle())
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(HoverHighlightStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 2)

        // Resize handle
        ResizeHandle(isDragging: $isDragging) { delta in
            let newHeight = (panelHeight + delta).clamped(min: 300, max: 900)
            panelHeight = newHeight
            UserDefaults.standard.set(Double(newHeight), forKey: "timezones_panelHeight")
        }
    }

    func selectAdjacentTimezone(offset: Int) {
        let sorted = store.sortedTimezones(for: selectedDate)
        guard !sorted.isEmpty else { return }
        if let currentIdx = sorted.firstIndex(where: { $0.identifier == store.referenceTimezoneId }) {
            let newIdx = currentIdx + offset
            guard newIdx >= 0 && newIdx < sorted.count else { return }
            store.referenceTimezoneId = sorted[newIdx].identifier
        } else {
            store.referenceTimezoneId = sorted[0].identifier
        }
    }

    var offsetLabel: String {
        let h = Int(store.hourOffset)
        let m = Int((store.hourOffset - Double(h)) * 60)
        let sign = store.hourOffset >= 0 ? "+" : ""
        if m == 0 {
            return "\(sign)\(h)h from now"
        } else {
            return "\(sign)\(h)h \(abs(m))m from now"
        }
    }
}

struct ResetButtonStyle: ButtonStyle {
    let isActive: Bool
    @State private var isHovered = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor(pressed: configuration.isPressed))
            )
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
    }
    private func backgroundColor(pressed: Bool) -> Color {
        if !isActive {
            return Color.primary.opacity(0.025)
        }
        if pressed { return Color.primary.opacity(0.26) }
        if isHovered { return Color.primary.opacity(0.30) }
        return Color.primary.opacity(0.23)
    }
}

struct TightLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
            configuration.title
        }
    }
}

struct HoverHighlightStyle: ButtonStyle {
    @State private var isHovered = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.primary.opacity(isHovered ? 0.12 : 0))
            )
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}
