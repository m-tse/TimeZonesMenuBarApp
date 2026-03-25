import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: TimezoneStore
    @State private var now = Date()
    @State private var showingAdd = false
    @State private var panelHeight: CGFloat = {
        let saved = UserDefaults.standard.double(forKey: "worldclock_panelHeight")
        return CGFloat(saved > 0 ? saved : 500).clamped(min: 300, max: 900)
    }()
    @State private var isDragging = false

    let timer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    var selectedDate: Date {
        now.addingTimeInterval(store.hourOffset * 3600)
    }

    var body: some View {
        VStack(spacing: 0) {
            if showingAdd {
                AddTimezoneView(isShowing: $showingAdd)
                    .environmentObject(store)
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
                        isHighlighted: isReference
                    )
                    .onTapGesture {
                        store.referenceTimezoneId = tz.timeZone.identifier
                    }
                    .contextMenu {
                        Button(isReference ? "Reference timezone" : "Set as reference") {
                            store.referenceTimezoneId = tz.timeZone.identifier
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
            UserDefaults.standard.set(Double(newHeight), forKey: "worldclock_panelHeight")
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
