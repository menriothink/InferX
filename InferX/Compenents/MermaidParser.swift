//
//  MermaidParser.swift
//  InferX
//
//  Created by mingdw on 2025/6/22.
//

import SwiftUI
import Charts
import Foundation

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let group: String?
    
    init(label: String, value: Double, group: String? = nil) {
        self.label = label
        self.value = value
        self.group = group
    }
}

struct ParsedChart {
    enum ChartType {
        case bar
        case line
        case pie
    }
    
    let type: ChartType
    let title: String?
    let data: [ChartDataPoint]
}

class MermaidParser {
    
    static func parse(mermaidCode: String) -> ParsedChart? {
        let trimmedCode = mermaidCode.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedCode.hasPrefix("pie") {
            return parsePieChart(code: trimmedCode)
        } else if trimmedCode.hasPrefix("graph") {
            return parseBarOrLineChart(code: trimmedCode)
        }
        
        return nil
    }
    
    private static func parsePieChart(code: String) -> ParsedChart? {
        var title: String?
        var dataPoints: [ChartDataPoint] = []
        
        let lines = code.split(whereSeparator: \.isNewline)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if let titleMatch = trimmedLine.range(of: #"^title\s+(.*)$"#, options: .regularExpression) {
                title = String(trimmedLine[titleMatch].dropFirst("title ".count))
                continue
            }
            
            let components = trimmedLine.split(separator: ":").map { $0.trimmingCharacters(in: .whitespaces) }
            if components.count == 2 {
                let label = components[0].replacingOccurrences(of: "\"", with: "")
                if let value = Double(components[1]) {
                    dataPoints.append(ChartDataPoint(label: label, value: value))
                }
            }
        }
        
        guard !dataPoints.isEmpty else { return nil }
        return ParsedChart(type: .pie, title: title, data: dataPoints)
    }
    
    private static func parseBarOrLineChart(code: String) -> ParsedChart? {
        var dataPoints: [ChartDataPoint] = []
        
        let nodeRegex = try! NSRegularExpression(pattern: #"\[(.*?):\s*([\d.]+)\]"#)
        let matches = nodeRegex.matches(in: code, range: NSRange(code.startIndex..., in: code))
        
        for match in matches {
            guard let labelRange = Range(match.range(at: 1), in: code),
                  let valueRange = Range(match.range(at: 2), in: code) else { continue }
            
            let label = String(code[labelRange])
            if let value = Double(String(code[valueRange])) {
                dataPoints.append(ChartDataPoint(label: label, value: value))
            }
        }
        
        guard !dataPoints.isEmpty else { return nil }
        let type: ParsedChart.ChartType = code.contains("%% type: line") ? .line : .bar
        
        return ParsedChart(type: type, title: nil, data: dataPoints)
    }
}

struct NativeChartView: View {
    let chartInfo: ParsedChart
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title = chartInfo.title {
                Text(title)
                    .font(.headline)
            }
            
            switch chartInfo.type {
            case .bar:
                BarChartView(data: chartInfo.data)
            case .line:
                LineChartView(data: chartInfo.data)
            case .pie:
                PieChartView(data: chartInfo.data)
            }
        }
        .padding()
        .background(.secondary)
        .cornerRadius(12)
        .padding(.vertical, 10)
    }
}

struct BarChartView: View {
    let data: [ChartDataPoint]
    
    var body: some View {
        Chart(data) { point in
            BarMark(
                x: .value("Label", point.label),
                y: .value("Value", point.value)
            )
            .foregroundStyle(by: .value("Label", point.label))
        }
        .chartLegend(.hidden)
        .frame(height: 250)
    }
}

struct LineChartView: View {
    let data: [ChartDataPoint]
    
    var body: some View {
        Chart(data) { point in
            LineMark(
                x: .value("Label", point.label),
                y: .value("Value", point.value)
            )
            PointMark(
                x: .value("Label", point.label),
                y: .value("Value", point.value)
            )
        }
        .frame(height: 250)
    }
}

struct PieChartView: View {
    let data: [ChartDataPoint]
    
    var body: some View {
        Chart(data) { point in
            SectorMark(
                angle: .value("Value", point.value),
                innerRadius: .ratio(0.5),
                angularInset: 2.0
            )
            .foregroundStyle(by: .value("Label", point.label))
            .annotation(position: .overlay) {
                Text("\(String(format: "%.0f", point.value))")
                    .font(.caption)
                    .foregroundColor(.white)
                    .bold()
            }
        }
        .chartLegend(position: .bottom, alignment: .center)
        .frame(height: 300)
    }
}
