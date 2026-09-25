import SwiftUI

struct SplashView: View {
    let continueAction: () -> Void
    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    Spacer()
                    PipMascot().frame(width: proxy.size.height < 500 ? 130 : 210,
                                      height: proxy.size.height < 500 ? 130 : 210)
                    VStack(spacing: 12) {
                        Text("Clearspace").font(.system(size: 42, weight: .bold, design: .rounded))
                        Text("A little less clutter.\nA little more breathing room.")
                            .font(.title3).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    Spacer()
                    Label("On your device. In your control.", systemImage: "lock.shield")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button(action: continueAction) {
                        HStack { Text("Make some room"); Image(systemName: "arrow.right") }
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
                    }.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                }.frame(maxWidth: .infinity, minHeight: max(0, proxy.size.height - 56)).padding(28)
            }
        }.background(Color(uiColor: .systemGroupedBackground))
    }
}
