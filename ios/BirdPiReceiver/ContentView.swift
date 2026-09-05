import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        NavigationStack {
            List {
                Section("Receiver") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(state.isServerRunning ? "listening on :8765" : "stopped")
                            .foregroundStyle(state.isServerRunning ? .green : .gray)
                    }
                    HStack {
                        Text("Phone IP (set as WS_HOST in firmware)")
                        Spacer()
                        Text(state.phoneIP).monospaced()
                    }
                    HStack {
                        Text("Frames received")
                        Spacer()
                        Text("\(state.framesReceived)").monospaced()
                    }
                    Button(state.isServerRunning ? "Running" : "Start") { state.start() }
                        .disabled(state.isServerRunning)
                }
                Section("Detections") {
                    if state.detections.isEmpty {
                        Text("No chirps classified yet.").foregroundStyle(.gray)
                    }
                    ForEach(state.detections) { d in
                        HStack {
                            Text(d.species)
                            Spacer()
                            Text(String(format: "%.0f%%", d.confidence * 100))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("BirdPi")
        }
    }
}
