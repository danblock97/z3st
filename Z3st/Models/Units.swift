import Foundation

public enum VolumeUnit: String, CaseIterable, Codable {
    case ml = "mL"
    case oz = "oz"

    func toML(_ value: Double) -> Int {
        switch self {
        case .ml: return Int(round(value))
        case .oz: return Int(round(value * 29.5735))
        }
    }

    func fromML(_ ml: Int) -> Double {
        switch self {
        case .ml: return Double(ml)
        case .oz: return Double(ml) / 29.5735
        }
    }
}

struct Presets: Codable, Equatable {
    var amountsML: [Int] // stored in ML internally
    static let `default` = Presets(amountsML: [150, 250, 350, 500, 750])
}
