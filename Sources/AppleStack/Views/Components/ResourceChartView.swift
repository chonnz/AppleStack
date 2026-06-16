import SwiftUI
import Charts

/// 资源监控图表视图
struct ResourceChartView: View {
    let dataPoints: [ResourceDataPoint]
    let title: String
    let color: Color
    let currentValue: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(currentValue)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(color)
            }

            if dataPoints.isEmpty {
                VStack {
                    Spacer()
                    Text("No data yet")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(height: 80)
            } else {
                Chart(dataPoints) { point in
                    AreaMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(color.opacity(0.3))
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(color)
                    .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            Text("\(value.as(Int.self) ?? 0)%")
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
                .frame(height: 80)
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

    var body: some View {
        VStack(spacing: 16) {
            ResourceChartView(
                dataPoints: cpuHistory,
                title: "CPU Usage",
                color: .blue,
                currentValue: currentCPU
            )

            ResourceChartView(
                dataPoints: memoryHistory,
                title: "Memory Usage",
                color: .purple,
                currentValue: currentMemory
            )
        }
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
        currentMemory: "67.50%"
    )
    .padding()
    .frame(width: 400, height: 250)
}
