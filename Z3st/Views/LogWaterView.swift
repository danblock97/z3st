import SwiftUI
import UIKit

struct LogWaterView: View {
    @StateObject private var vm = WaterViewModel()
    @State private var amount: Int = 250
    @AppStorage("unit") private var unitRaw: String = VolumeUnit.ml.rawValue
    @AppStorage("presets_ml") private var presetsData: Data = {
        try! JSONEncoder().encode(Presets.default)
    }()

    var unit: VolumeUnit { VolumeUnit(rawValue: unitRaw) ?? .ml }
    var presets: Presets { (try? JSONDecoder().decode(Presets.self, from: presetsData)) ?? .default }
    @State private var justLoggedMessage: String?
    @State private var showLoggedBanner = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Quick Log")
                    .font(.title2).bold()
                // Preset grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(presets.amountsML, id: \.self) { ml in
                        let display = unit == .ml ? "\(ml) mL" : String(format: "%.0f oz", unit.fromML(ml))
                        Button(display) {
                            Task { await logAndAcknowledge(ml) }
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Log \(display)")
                    }
                }
                .padding(.horizontal, 4)

                Picker("Amount", selection: Binding(get: {
                    amount
                }, set: { newVal in
                    amount = newVal
                })) {
                    ForEach([150, 200, 250, 300, 350, 500, 750, 1000], id: \.self) { val in
                        let display = unit == .ml ? "\(val) mL" : String(format: "%.0f oz", unit.fromML(val))
                        Text(display).tag(val)
                    }
                }
                .pickerStyle(.segmented)

                Button(action: { Task { await logAndAcknowledge(amount) } }) {
                    let display = unit == .ml ? "\(amount) mL" : String(format: "%.0f oz", unit.fromML(amount))
                    Label("Log \(display)", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
            }
            .padding()
            .overlay(alignment: .bottom) {
                if showLoggedBanner, let msg = justLoggedMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        Text(msg).bold()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        .navigationTitle("Log Water")
        .toolbar {
            NavigationLink(destination: UnitsPresetsSettingsView()) { Image(systemName: "slider.horizontal.3") }
        }
        }
    }

    private func logAndAcknowledge(_ ml: Int) async {
        let success = await vm.log(amount: ml)
        await MainActor.run {
            let display = unit == .ml ? "\(ml) mL" : String(format: "%.0f oz", unit.fromML(ml))
            if success {
                let generator = UINotificationFeedbackGenerator(); generator.notificationOccurred(.success)
                justLoggedMessage = "Logged \(display)"
            } else {
                let generator = UINotificationFeedbackGenerator(); generator.notificationOccurred(.error)
                justLoggedMessage = "Couldn’t log \(display)"
            }
            withAnimation { showLoggedBanner = true }
        }
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        await MainActor.run { withAnimation { showLoggedBanner = false } }
    }
}

struct UnitsPresetsSettingsView: View {
    @AppStorage("unit") private var unitRaw: String = VolumeUnit.ml.rawValue
    @AppStorage("presets_ml") private var presetsData: Data = try! JSONEncoder().encode(Presets.default)
    @State private var list: [Int] = Presets.default.amountsML
    var unit: VolumeUnit { VolumeUnit(rawValue: unitRaw) ?? .ml }
    var body: some View {
        Form {
            Section(header: Text("Units")) {
                Picker("Unit", selection: $unitRaw) {
                    ForEach(VolumeUnit.allCases, id: \.self) { u in
                        Text(u.rawValue).tag(u.rawValue)
                    }
                }
            }
            Section(header: Text("Presets"), footer: Text("Stored internally in mL; displayed in selected units.")) {
                ForEach(Array(list.enumerated()), id: \.offset) { idx, ml in
                    HStack {
                        let display = unit == .ml ? "\(ml) mL" : String(format: "%.0f oz", unit.fromML(ml))
                        Text("Preset #\(idx+1)")
                        Spacer()
                        Text(display).foregroundStyle(.secondary)
                    }
                }
                .onDelete { offsets in list.remove(atOffsets: offsets) }
                Button("Add preset") {
                    let next = (list.last ?? 250) + 100
                    list.append(next)
                }
            }
        }
        .navigationTitle("Units & Presets")
        .onAppear { list = (try? JSONDecoder().decode(Presets.self, from: presetsData))?.amountsML ?? Presets.default.amountsML }
        .onDisappear {
            let p = Presets(amountsML: list)
            if let data = try? JSONEncoder().encode(p) { presetsData = data }
            // Mirror unit to App Group for widget display
            if let defaults = AppGroupManager.defaults() {
                defaults.set(unitRaw, forKey: "unit")
            }
        }
    }
}
