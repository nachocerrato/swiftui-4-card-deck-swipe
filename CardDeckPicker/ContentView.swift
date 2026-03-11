import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 64)

            CardDeckPickerView()
                .frame(maxWidth: .infinity)
                .frame(height: 356)
                .padding(.horizontal, 20)

            Text("A 4-card swipe transition with an asymmetric right swipe: the previous card comes out from behind the stack before it takes the front spot.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 24)
                .padding(.horizontal, 28)

            Spacer()
        }
        .background(Color(red: 0.92, green: 0.92, blue: 0.95))
    }
}

#Preview {
    ContentView()
}
