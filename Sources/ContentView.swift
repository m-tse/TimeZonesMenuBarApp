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
    @State private var showingDatePicker = false
    @State private var pickerDate = Date()

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
            } else {
                mainView
            }
        }
        .frame(width: 360, height: panelHeight)
        .onReceive(timer) { _ in
            now = Date()
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
                .padding(.horizontal, 16)
                .onChange(of: pickerDate) { newDate in
                    let now = Date()
                    let diff = newDate.timeIntervalSince(now) / 3600.0
                    store.hourOffset = (diff * 60).rounded() / 60
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
                    let isReference = tz.timeZone.identifier == store.referenceTimezoneId
                    TimezoneRowView(
                        timezone: tz,
                        selectedDate: selectedDate,
                        localTimeZone: store.referenceTimeZone,
                        hourOffset: $store.hourOffset,
                        isHighlighted: isReference,
                        use24Hour: store.use24Hour,
                        onDateTap: {
                            pickerDate = selectedDate
                            showingDatePicker = true
                        }
                    )
                    .onTapGesture {
                        store.referenceTimezoneId = tz.timeZone.identifier
                    }
                    .contextMenu {
                        Button(isReference ? "Reference timezone" : "Set as reference") {
                            store.referenceTimezoneId = tz.timeZone.identifier
                        }
                        Button("Rename…") {
                            renameText = tz.label
                            renamingTimezone = tz
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
        ZStack {
            // Reset centered
            Button("Reset") {
                withAnimation(.easeOut(duration: 0.3)) {
                    store.hourOffset = 0
                }
            }
            .buttonStyle(.borderless)
            .font(.system(size: 12))
            .disabled(store.hourOffset == 0)
            .opacity(store.hourOffset != 0 ? 1 : 0.4)

            // Add left, Quit right
            HStack {
                Button { showingAdd = true } label: {
                    Label("Add", systemImage: "plus")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                Spacer()
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
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
