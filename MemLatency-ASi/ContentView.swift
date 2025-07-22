//
//  ContentView.swift
//  MemLatency-ASi
//
//  Created by Celestial紗雪 on 2025/7/22.
//

import SwiftUI
import Charts
import UniformTypeIdentifiers

struct TestResult: Codable, Equatable, Hashable {
    let sizeKb: Int
    let latency: Double
}

struct TestResultDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var results: [TestResult]

    init(results: [TestResult]) {
        self.results = results
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.results = try JSONDecoder().decode([TestResult].self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(self.results)
        return FileWrapper(regularFileWithContents: data)
    }
}

struct TestRun: Identifiable, Equatable, Hashable {
    let id = UUID()
    let coreType: String
    let timestamp: Date
    var results: [TestResult]
}

struct TestParameter: Identifiable, Hashable {
    var id = UUID()
    var size: String
    var iterations: String
}

class AppViewModel: ObservableObject {
    @Published var history: [TestRun] = []
    @Published var selectedRunID: UUID?
    
    @Published var isTesting = false
    @Published var testOnECore = false
    @Published var statusMessage = "Click to start the test"
    
    @Published var isShowingSettings = false
    @Published var testParametersList: [TestParameter] = [
        .init(size: "1", iterations: "3000000000"),
        .init(size: "2", iterations: "750000000"),
        .init(size: "4", iterations: "750000000"),
        .init(size: "6", iterations: "750000000"),
        .init(size: "8", iterations: "750000000"),
        .init(size: "12", iterations: "750000000"),
        .init(size: "16", iterations: "750000000"),
        .init(size: "24", iterations: "750000000"),
        .init(size: "32", iterations: "750000000"),
        .init(size: "48", iterations: "750000000"),
        .init(size: "64", iterations: "750000000"),
        .init(size: "96", iterations: "750000000"),
        .init(size: "128", iterations: "750000000"),
        .init(size: "192", iterations: "330000000"),
        .init(size: "256", iterations: "220000000"),
        .init(size: "384", iterations: "170000000"),
        .init(size: "512", iterations: "170000000"),
        .init(size: "600", iterations: "170000000"),
        .init(size: "768", iterations: "170000000"),
        .init(size: "1024", iterations: "140000000"),
        .init(size: "2048", iterations: "140000000"),
        .init(size: "3072", iterations: "120000000"),
        .init(size: "4096", iterations: "120000000"),
        .init(size: "6144", iterations: "90000000"),
        .init(size: "8192", iterations: "73000000"),
        .init(size: "10240", iterations: "40000000"),
        .init(size: "12288", iterations: "33000000"),
        .init(size: "16384", iterations: "33000000"),
        .init(size: "20480", iterations: "27000000"),
        .init(size: "24576", iterations: "19000000"),
        .init(size: "32768", iterations: "17000000"),
        .init(size: "49152", iterations: "12000000"),
        .init(size: "65536", iterations: "12000000"),
        .init(size: "98304", iterations: "7000000"),
        .init(size: "131072", iterations: "1500000"),
        .init(size: "262144", iterations: "1500000")
    ]
    
    func addNewParameterRow() {
        testParametersList.append(TestParameter(size: "", iterations: ""))
    }
    
    func removeParameterRow(id: UUID) {
        testParametersList.removeAll { $0.id == id }
    }

    var testParameters: [NSNumber: NSNumber] {
        var params: [NSNumber: NSNumber] = [:]
        for param in testParametersList {
            if let size = Int(param.size.trimmingCharacters(in: .whitespaces)),
                let iterations = Int(param.iterations.trimmingCharacters(in: .whitespaces)),
                size > 0 && iterations > 0 {
                params[NSNumber(value: size)] = NSNumber(value: iterations)
            }
        }
        return params
    }
    
    private let memoryTester = MemoryLatencyTester()

    var selectedResults: [TestResult] {
        guard let selectedRunID = selectedRunID,
              let run = history.first(where: { $0.id == selectedRunID }) else {
            return []
        }
        return run.results
    }
    
    func startTesting() {
        guard !isTesting else { return }
            
        isTesting = true
        let coreName = testOnECore ? "Efficiency Core" : "Performance Core"
        statusMessage = "Preparing test on \(coreName)..."
            
        let newRun = TestRun(coreType: coreName, timestamp: Date(), results: [])
        history.append(newRun)
        if selectedRunID == nil {
            selectedRunID = newRun.id
        }
            
        memoryTester.runLatencyTests(
            withParameters: self.testParameters,
            testOnECore: self.testOnECore,
            progress: { latency, sizeKb in
                DispatchQueue.main.async {
                    if let index = self.history.firstIndex(where: { $0.id == newRun.id }) {
                        let result = TestResult(sizeKb: Int(sizeKb), latency: latency)
                        self.history[index].results.append(result)
                        self.history[index].results.sort { $0.sizeKb < $1.sizeKb }
                        self.statusMessage = "Testing (\(coreName)): \(sizeKb)KB, Latency: \(String(format: "%.2f", latency)) ns"
                    }
                }
            },
            completion: {
                DispatchQueue.main.async {
                    self.isTesting = false
                    self.statusMessage = "Test complete!"
                }
            }
        )
    }
}

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @State private var isExporting = false
    @State private var documentToExport: TestResultDocument?
    
    @State private var isShowingHistorySheet = false

    var body: some View {
        #if os(macOS)
        macOSContentView
        #else
        if UIDevice.current.userInterfaceIdiom == .pad {
            macOSContentView
        } else {
            iOSContentView
        }
        #endif
    }
    
    private var macOSContentView: some View {
        NavigationSplitView {
            HistoryListView(viewModel: viewModel)
        } detail: {
            detailView
        }
        .sheet(isPresented: $viewModel.isShowingSettings) {
            SettingsView(viewModel: viewModel)
        }
        .fileExporter(isPresented: $isExporting, document: documentToExport, contentType: .json, defaultFilename: "LatencyReport-\(Date().formatted(.iso8601)).json") { result in
            handleFileExporterResult(result)
        }
    }
    
    private var iOSContentView: some View {
        NavigationView {
            detailView
                .sheet(isPresented: $isShowingHistorySheet) {
                    NavigationView {
                        HistoryListView(viewModel: viewModel)
                            .toolbar {
                                ToolbarItem(placement: .primaryAction) {
                                    Button("Done") {
                                        isShowingHistorySheet = false
                                    }
                                }
                            }
                    }
                }
        }
        #if os(iOS)
        .navigationViewStyle(.stack)
        #endif
        .sheet(isPresented: $viewModel.isShowingSettings) {
            SettingsView(viewModel: viewModel)
        }
        .fileExporter(isPresented: $isExporting, document: documentToExport, contentType: .json, defaultFilename: "LatencyReport-\(Date().formatted(.iso8601)).json") { result in
            handleFileExporterResult(result)
        }
    }
    
    private var detailView: some View {
        VStack(spacing: 0) {
            LatencyChartView(results: viewModel.selectedResults)
                .padding()
            Spacer()
            ControlPanelView(viewModel: viewModel)
        }
        .navigationTitle("Latency Results")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom != .pad {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { isShowingHistorySheet = true }) {
                        Label("History", systemImage: "list.bullet")
                    }
                }
            }
            #endif
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: exportAction) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .help("Export selected test data as JSON")
                .disabled(viewModel.selectedResults.isEmpty || viewModel.isTesting)
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: { viewModel.isShowingSettings = true }) {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .help("Open Test Settings")
            }
        }
    }
    
    private func exportAction() {
        self.documentToExport = TestResultDocument(results: viewModel.selectedResults)
        self.isExporting = true
    }
    
    private func handleFileExporterResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            print("Saved to \(url)")
        case .failure(let error):
            print("Save failed: \(error.localizedDescription)")
        }
    }
}

struct HistoryListView: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        List(viewModel.history, selection: $viewModel.selectedRunID) { run in
            HStack {
                Image(systemName: run.coreType == "Performance Core" ? "hare.fill" : "tortoise.fill")
                    .foregroundColor(run.coreType == "Performance Core" ? .red : .blue)
                VStack(alignment: .leading) {
                    Text(run.coreType)
                        .font(.headline)
                    Text(run.timestamp, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tag(run.id)
        }
        .navigationTitle("Test History")
        .listStyle(.sidebar)
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            VStack {
                Text("Test Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Specify each test size and its corresponding iteration count.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            ScrollView {
                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                    GridRow {
                        Text("Size (KB)")
                        Text("Iterations")
                        Color.clear.frame(width: 20)
                    }
                    .font(.headline)
                    .padding(.bottom, 5)

                    ForEach($viewModel.testParametersList) { $param in
                        GridRow {
                            TextField("e.g., 64", text: $param.size)
                                .textFieldStyle(.roundedBorder)
                            TextField("e.g., 300M", text: $param.iterations)
                                .textFieldStyle(.roundedBorder)
                            Button(action: { viewModel.removeParameterRow(id: param.id) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            
            Divider()
            
            HStack {
                Button(action: viewModel.addNewParameterRow) {
                    Label("Add Row", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.bar)
        }
        .frame(minWidth: 500, minHeight: 450, idealHeight: 500, maxHeight: 700)
    }
}

struct LatencyChartView: View {
    let results: [TestResult]
    @State private var selectedResult: TestResult?

    var body: some View {
        VStack {
            Text("Memory Access Latency (ns)")
                .font(.headline)
            
            if results.isEmpty {
                Spacer()
                Text("Select a test from the history, or start a new test.")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                Chart(results, id: \.self) { result in
                    BarMark(
                        x: .value("Block Size", formatSize(result.sizeKb)),
                        y: .value("Latency (ns)", result.latency)
                    )
                    .foregroundStyle(latencyColor(result.latency))
                    .opacity(selectedResult == nil || selectedResult == result ? 1.0 : 0.5)
                }
                .animation(.default, value: results)
                .chartOverlay { proxy in
                    overlayContent(proxy: proxy)
                }
                .padding()
                .background(chartBackground)
            }
        }
    }
    
    @ViewBuilder
    private var chartBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            #if os(macOS)
            .fill(Color(nsColor: .textBackgroundColor))
            #else
            .fill(Color(uiColor: .secondarySystemBackground))
            #endif
    }
    
    @ViewBuilder
    private func overlayContent(proxy: ChartProxy) -> some View {
        GeometryReader { geometry in
            Rectangle().fill(.clear).contentShape(Rectangle())
                .onContinuousHover { phase in
                    handleHover(phase: phase, proxy: proxy)
                }

            if let selectedResult {
                annotation(for: selectedResult, proxy: proxy, geometry: geometry)
            }
        }
    }

    @ViewBuilder
    private func annotation(for result: TestResult, proxy: ChartProxy, geometry: GeometryProxy) -> some View {
        if let index = results.firstIndex(of: result) {
            let chartFrame = geometry[proxy.plotAreaFrame]
            let barCount = results.count
            
            if barCount > 0 {
                let bandWidth = proxy.plotAreaSize.width / CGFloat(barCount)
                let xPosition = bandWidth * (CGFloat(index) + 0.5)

                Rectangle()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 1, height: chartFrame.height)
                    .offset(x: chartFrame.minX + xPosition)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Size: \(formatSize(result.sizeKb))")
                    Text("Latency: \(String(format: "%.2f", result.latency)) ns")
                }
                .font(.caption)
                .padding(8)
                .background(annotationBackground)
                .position(x: chartFrame.minX + xPosition, y: chartFrame.minY - 25)
            }
        } else {
            EmptyView()
        }
    }
    
    private var annotationBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            #if os(macOS)
            .fill(Color(nsColor: .windowBackgroundColor).opacity(0.8))
            #else
            .fill(Color(uiColor: .systemBackground).opacity(0.8))
            #endif
            .shadow(radius: 3)
    }
    
    private func handleHover(phase: HoverPhase, proxy: ChartProxy) {
        switch phase {
        case .active(let location):
            let barCount = results.count
            guard barCount > 0 else { return }
            let bandWidth = proxy.plotAreaSize.width / CGFloat(barCount)
            let index = Int(location.x / bandWidth)
            if index >= 0 && index < barCount {
                self.selectedResult = results[index]
            } else {
                self.selectedResult = nil
            }
        case .ended:
            self.selectedResult = nil
        }
    }
    
    private func formatSize(_ kb: Int) -> String {
        if kb >= 1024 {
            return "\(kb / 1024)M"
        }
        return "\(kb)K"
    }
    
    private func latencyColor(_ latency: Double) -> Color {
        if latency > 100 { return .red }
        if latency > 30 { return .orange }
        return .blue
    }
}

struct ControlPanelView: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        VStack(spacing: 15) {
            Text(viewModel.statusMessage)
                .font(.footnote)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            HStack(spacing: 12) {
                Button(action: {
                    viewModel.testOnECore.toggle()
                }) {
                    Text(viewModel.testOnECore ? "Efficiency Core" : "Performance Core")
                        .fontWeight(.medium)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.testOnECore ? .blue : .red)
                .disabled(viewModel.isTesting)

                Button(action: {
                    viewModel.startTesting()
                }) {
                    HStack {
                        Image(systemName: viewModel.isTesting ? "hourglass" : "play.fill")
                        Text(viewModel.isTesting ? "Testing..." : "Start Test")
                    }
                    .fontWeight(.bold)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(viewModel.isTesting)
            }
        }
        .padding()
        .background(.regularMaterial)
    }
}
