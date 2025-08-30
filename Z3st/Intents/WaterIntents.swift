import Foundation
import AppIntents

@available(iOS 16.0, *)
struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Water"
    static var description = IntentDescription("Log a water amount using Z3st.")

    @Parameter(title: "Amount", default: 250)
    var amount: Int

    @Parameter(title: "Unit", default: UnitChoice.ml)
    var unit: UnitChoice

    static var parameterSummary: some ParameterSummary {
        Summary("Log")
    }

    func perform() async throws -> some IntentResult {
        let ml: Int
        switch unit {
        case .ml: ml = amount
        case .oz: ml = Int(round(Double(amount) * 29.5735))
        }
        try await WaterService.shared.logWater(volumeML: ml)
        NotificationService.shared.scheduleInactivityNudge(after: UserDefaults.standard.integer(forKey: "inactivity_hours"))
        return .result(value: "Logged \(ml) mL")
    }
}

@available(iOS 16.0, *)
enum UnitChoice: String, AppEnum {
    case ml = "mL"
    case oz = "oz"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Unit"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .ml: "mL",
        .oz: "oz"
    ]
}
