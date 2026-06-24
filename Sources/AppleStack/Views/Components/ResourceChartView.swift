import SwiftUI
import Charts

/// 资源监控图表视图
struct ResourceChartView: View {
    let dataPoints: [ResourceDataPoint]
    let title: String
    let color: Color
    let currentValue: String
    var subtitle: String?
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    private var minValue: Double {
        dataPoints.map(\.value).min() ?? 0
    }

    private var maxValue: Double {
        dataPoints.map(\.value).max() ?? 0
    }

    private var chartLowerBound: Double {
        guard !dataPoints.isEmpty else { return 0 }
        let spread = max(maxValue - minValue, 2)
        let padded = minValue - (spread * 0.35)
        return max(0, floor(padded / 5) * 5)
    }

    private var chartUpperBound: Double {
        let spread = max(maxValue - minValue, 2)
        let baseline = max(maxValue + (spread * 0.35), 10)
        return ceil(baseline / 5) * 5
    }

    private var lastPoint: ResourceDataPoint? {
        dataPoints.last
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                Text(currentValue)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(color)
            }

            if dataPoints.isEmpty {
                VStack {
                    Spacer()
                    Text(language.localized("No data yet"))
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(height: 80)
            } else {
                Chart(dataPoints) { point in
                    AreaMark(
                        x: .value("Time", point.timestamp),
                        yStart: .value("Baseline", chartLowerBound),
                        yEnd: .value("Value", point.value)
                    )
                    .foregroundStyle(color.opacity(0.3))
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(color)
                    .interpolationMethod(.catmullRom)

                    if dataPoints.count <= 12 || point.id == dataPoints.last?.id {
                        PointMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(color)
                        .symbolSize(point.id == dataPoints.last?.id ? 28 : 14)
                    }
                }
                .chartYScale(domain: chartLowerBound...chartUpperBound)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            Text("\(Int(value.as(Double.self) ?? 0))%")
                                .font(.system(size: 10))
                        }
                        AxisGridLine()
                    }
                }
                .chartXAxis {
                    AxisMarks(position: .bottom) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date, style: .time)
                                    .font(.system(size: 10))
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        if let lastPoint,
                           let xPosition = proxy.position(forX: lastPoint.timestamp),
                           let yPosition = proxy.position(forY: lastPoint.value) {
                            Text(String(format: "%.1f%%", lastPoint.value))
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(color)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.92))
                                )
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(color.opacity(0.25), lineWidth: 0.8)
                                )
                                .position(
                                    x: min(max(xPosition, 32), geometry.size.width - 32),
                                    y: max(yPosition - 14, 10)
                                )
                        }
                    }
                }
                .frame(height: 96)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// 资源数据点
struct ResourceDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
}

/// 简单的条形图视图
struct SimpleBarChartView: View {
    let segments: [BarSegment]
    let maxValue: Double

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(segments) { segment in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(segment.color)
                        .frame(width: max(2, geometry.size.width / CGFloat(segments.count) - 2))
                        .frame(height: geometry.size.height * (segment.value / maxValue))
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
    }
}

/// 条形图段
struct BarSegment: Identifiable {
    let id = UUID()
    let value: Double
    let color: Color
}

/// 监控仪表盘视图
struct MonitorDashboardView: View {
    let cpuHistory: [ResourceDataPoint]
    let memoryHistory: [ResourceDataPoint]
    let currentCPU: String
    let currentMemory: String
    var cpuSubtitle: String?
    var memorySubtitle: String?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                cpuChart
                memoryChart
            }

            VStack(spacing: 16) {
                cpuChart
                memoryChart
            }
        }
    }

    private var cpuChart: some View {
        ResourceChartView(
            dataPoints: cpuHistory,
            title: "CPU Usage",
            color: .blue,
            currentValue: currentCPU,
            subtitle: cpuSubtitle
        )
    }

    private var memoryChart: some View {
        ResourceChartView(
            dataPoints: memoryHistory,
            title: "Memory Usage",
            color: .purple,
            currentValue: currentMemory,
            subtitle: memorySubtitle
        )
    }
}

#Preview {
    MonitorDashboardView(
        cpuHistory: [
            ResourceDataPoint(timestamp: Date().addingTimeInterval(-300), value: 25),
            ResourceDataPoint(timestamp: Date().addingTimeInterval(-240), value: 35),
            ResourceDataPoint(timestamp: Date().addingTimeInterval(-180), value: 45),
            ResourceDataPoint(timestamp: Date().addingTimeInterval(-120), value: 30),
            ResourceDataPoint(timestamp: Date().addingTimeInterval(-60), value: 55),
            ResourceDataPoint(timestamp: Date(), value: 40),
        ],
        memoryHistory: [
            ResourceDataPoint(timestamp: Date().addingTimeInterval(-300), value: 60),
            ResourceDataPoint(timestamp: Date().addingTimeInterval(-240), value: 62),
            ResourceDataPoint(timestamp: Date().addingTimeInterval(-180), value: 65),
            ResourceDataPoint(timestamp: Date().addingTimeInterval(-120), value: 63),
            ResourceDataPoint(timestamp: Date().addingTimeInterval(-60), value: 68),
            ResourceDataPoint(timestamp: Date(), value: 67),
        ],
        currentCPU: "40.25%",
        currentMemory: "67.50%",
        cpuSubtitle: "Peak 55%",
        memorySubtitle: "Peak 68%"
    )
    .padding()
    .frame(width: 400, height: 250)
}
