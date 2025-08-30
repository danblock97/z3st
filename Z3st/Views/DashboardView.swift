import SwiftUI
import Charts

struct DashboardView: View {
    @StateObject private var vm = WaterViewModel()
    @State private var range: HistoryRange = .last7D
    @AppStorage("chart_style") private var chartStyleRaw: String = ChartStyle.line.rawValue

    enum ChartStyle: String, CaseIterable { case line = "Line", area = "Area" }
    @State private var profile: UserProfile?
    @State private var shareURL: URL?
    @State private var isSharing: Bool = false
    @State private var showRefreshedBanner = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                SummaryCard(todayTotal: vm.todayTotal, goal: profile?.daily_goal_ml)

                HStack {
                    Picker("Range", selection: $range) {
                        ForEach(HistoryRange.allCases, id: \.self) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                    .pickerStyle(.segmented)

                    if #available(iOS 16.0, *) {
                        Picker("Style", selection: $chartStyleRaw) {
                            ForEach(ChartStyle.allCases, id: \.self) { s in
                                Text(s.rawValue).tag(s.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 160)
                    }
                }

                if vm.history.isEmpty {
                    ContentUnavailableView("No water logged", systemImage: "drop", description: Text("Start logging to see your history."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 12) {
                        if #available(iOS 16.0, *) {
                            Chart(vm.history) { item in
                                let date = ISO8601DateFormatter.dateFormatterYYYYMMDD.date(from: item.dateString) ?? Date()
                                let style = ChartStyle(rawValue: chartStyleRaw) ?? .line
                                switch style {
                                case .line:
                                    LineMark(
                                        x: .value("Date", date, unit: .day),
                                        y: .value("ml", item.total_ml)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(.accent)
                                    PointMark(
                                        x: .value("Date", date, unit: .day),
                                        y: .value("ml", item.total_ml)
                                    )
                                    .foregroundStyle(.accent)
                                case .area:
                                    AreaMark(
                                        x: .value("Date", date, unit: .day),
                                        y: .value("ml", item.total_ml)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(.linearGradient(
                                        colors: [.accentColor.opacity(0.6), .accentColor.opacity(0.1)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ))
                                    LineMark(
                                        x: .value("Date", date, unit: .day),
                                        y: .value("ml", item.total_ml)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(.accent)
                                }
                            }
                            .chartYScale(domain: 0...max( (vm.history.map{ $0.total_ml }.max() ?? 0) , 1000))
                            .frame(height: 220)
                        }
                        List(vm.history) { day in
                            HStack {
                                Text(day.dateString)
                                Spacer()
                                Text("\(day.total_ml) ml")
                                    .bold()
                            }
                        }
                        .listStyle(.plain)
                        .frame(maxHeight: 280)
                        .refreshable {
                            await vm.refresh(range: range)
                            await MainActor.run { withAnimation { showRefreshedBanner = true } }
                            try? await Task.sleep(nanoseconds: 1_200_000_000)
                            await MainActor.run { withAnimation { showRefreshedBanner = false } }
                        }
                    }
                }
            }
            .padding()
            .overlay(alignment: .top) {
                if showRefreshedBanner {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise.circle.fill").foregroundColor(.accentColor)
                        Text("Refreshed").bold()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if let ui = UIImage(named: "AppLogo") {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 20)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            .accessibilityLabel("Z3st")
                    } else {
                        Text("Z3st").font(.headline).bold()
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(destination: ProfileView()) {
                        ZStack {
                            if let urlStr = profile?.profile_url, let url = URL(string: urlStr) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty: ProgressView()
                                    case .success(let img): img.resizable().scaledToFill()
                                    case .failure: Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().padding(4)
                                    @unknown default: Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().padding(4)
                                    }
                                }
                            } else {
                                Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().padding(4)
                            }
                        }
                        .frame(width: 32, height: 32)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                        .accessibilityLabel("Profile")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let csv = ExportService.buildCSV(from: vm.history)
                        if let url = try? ExportService.writeTempCSV(csv) { shareURL = url; isSharing = true }
                    } label: { Image(systemName: "square.and.arrow.up") }
                    .disabled(vm.history.isEmpty)
                }
            }
            .task {
                await vm.refresh(range: range)
                profile = try? await UserService.shared.fetchMyProfile()
            }
            .onChange(of: range) { _, newValue in
                Task { await vm.refresh(range: newValue) }
            }
        }
        .sheet(isPresented: $isSharing) {
            if let url = shareURL { ShareSheet(activityItems: [url]) }
        }
    }
}

private struct SummaryCard: View {
    let todayTotal: Int
    let goal: Int?
    var progress: Double { guard let g = goal, g > 0 else { return 0 }; return min(1, Double(todayTotal)/Double(g)) }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today")
                .font(.headline)
            HStack {
                let unit = VolumeUnit(rawValue: UserDefaults.standard.string(forKey: "unit") ?? VolumeUnit.ml.rawValue) ?? .ml
                let value = unit == .ml ? Double(todayTotal) : unit.fromML(todayTotal)
                let formatted = unit == .ml ? String(format: "%.0f mL", value) : String(format: "%.0f oz", value)
                Text(formatted)
                    .font(.system(size: 34, weight: .bold))
                if let goal {
                    let gVal = unit == .ml ? Double(goal) : unit.fromML(goal)
                    let gStr = unit == .ml ? String(format: "%.0f mL", gVal) : String(format: "%.0f oz", gVal)
                    Text("/ \(gStr)")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            ProgressView(value: progress)
                .tint(.accentColor)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today's water total")
        .accessibilityValue(accessibilitySummary)
    }
    private var accessibilitySummary: String {
        if let goal { return "\(todayTotal) milliliters out of \(goal)" }
        return "\(todayTotal) milliliters"
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
