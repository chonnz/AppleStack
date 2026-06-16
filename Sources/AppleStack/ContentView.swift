import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("AppleStack")
                .font(.largeTitle)
            Text("Apple Container Management")
                .font(.title2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
}
