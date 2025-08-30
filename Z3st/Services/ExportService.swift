import Foundation
import UniformTypeIdentifiers

enum ExportService {
    static func buildCSV(from totals: [WaterDayTotal]) -> String {
        var lines = ["date,total_ml"]
        for t in totals.sorted(by: { $0.dateString < $1.dateString }) {
            lines.append("\(t.dateString),\(t.total_ml)")
        }
        return lines.joined(separator: "\n")
    }

    static func writeTempCSV(_ content: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("z3st_water_export_\(Int(Date().timeIntervalSince1970)).csv")
        try content.data(using: .utf8)?.write(to: url)
        return url
    }
}

