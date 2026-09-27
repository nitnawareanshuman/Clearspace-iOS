import SwiftUI

struct SwipeReviewView: View {
    let items: [PhotoItem]
    @Binding var selected: Set<String>
    let onExit: () -> Void
    let onReview: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var dragOffset: CGSize = .zero
    @State private var decisionNotice: String?

    private var current: PhotoItem? {
        guard index < items.count else { return nil }
        return items[index]
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Swipe to decide").font(.title2.bold())
                    Text("Right = keep · Left = queue for deletion")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Exit") { onExit() }.buttonStyle(.bordered)
            }

            Text("\(max(0, items.count - index)) photos left")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let item = current {
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))

                    PhotoThumbnail(item: item, large: true)
                        .clipShape(RoundedRectangle(cornerRadius: 28))

                    if abs(dragOffset.width) > 25 {
                        Text(dragOffset.width > 0 ? "KEEP" : "DELETE")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundStyle(dragOffset.width > 0 ? .teal : .red)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .rotationEffect(.degrees(dragOffset.width > 0 ? 7 : -7))
                    }

                    VStack {
                        HStack {
                            if item.favorite {
                                Label("Favorite", systemImage: "heart.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(8)
                                    .background(.black.opacity(0.35), in: Capsule())
                            }
                            Spacer()
                            Text(ByteSummary([item]).label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(.black.opacity(0.35), in: Capsule())
                        }

                        Spacer()

                        HStack {
                            Label("Delete", systemImage: "arrow.left")
                                .foregroundStyle(.white)
                            Spacer()
                            Label("Keep", systemImage: "arrow.right")
                                .foregroundStyle(.white)
                        }
                        .font(.caption.weight(.semibold))
                        .padding(12)
                        .background(.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(14)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 430)
                .offset(x: dragOffset.width)
                .rotationEffect(.degrees(Double(dragOffset.width) / 24))
                .gesture(
                    DragGesture(minimumDistance: 12)
                        .onChanged { value in dragOffset = value.translation }
                        .onEnded { value in
                            let threshold: CGFloat = 110
                            if value.translation.width > threshold {
                                decide(.keep)
                            } else if value.translation.width < -threshold {
                                decide(.delete)
                            } else {
                                resetCard()
                            }
                        }
                )
                .animation(
                    reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82),
                    value: dragOffset
                )

                HStack(spacing: 24) {
                    Button { decide(.delete) } label: {
                        Image(systemName: "trash")
                            .font(.title2)
                            .frame(width: 58, height: 58)
                            .background(.red.opacity(0.12), in: Circle())
                    }
                    .tint(.red)
                    .disabled(!item.canDelete)
                    .accessibilityLabel("Queue this photo for deletion")

                    Button { decide(.keep) } label: {
                        Image(systemName: "checkmark")
                            .font(.title2)
                            .frame(width: 58, height: 58)
                            .background(.teal.opacity(0.12), in: Circle())
                    }
                    .tint(.teal)
                    .accessibilityLabel("Keep this photo")

                    Button("Review \(selected.count)") { onReview() }
                        .buttonStyle(.borderedProminent)
                        .disabled(selected.isEmpty)
                }
            } else {
                Surface {
                    VStack(spacing: 10) {
                        PipMascot().frame(width: 110, height: 110)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(.teal)
                        Text("You're all caught up").font(.title2.bold())
                        Text("\(selected.count) photo(s) queued for review.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                HStack {
                    Button("Back to grid") { onExit() }.buttonStyle(.bordered)
                    Spacer()
                    Button("Review deletion") { onReview() }
                        .buttonStyle(.borderedProminent)
                        .disabled(selected.isEmpty)
                }
            }

            if let decisionNotice {
                Text(decisionNotice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text("Nothing is deleted while swiping. Your choices go to the normal review screen.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 4)
    }

    private enum Decision {
        case keep
        case delete
    }

    private func decide(_ decision: Decision) {
        guard let item = current else { return }

        if decision == .delete && !item.canDelete {
            decisionNotice = "This item is read-only and cannot be queued for deletion."
            goNext()
            return
        }

        switch decision {
        case .keep:
            selected.remove(item.id)
        case .delete:
            selected.insert(item.id)
        }

        goNext()
    }

    private func resetCard() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
            dragOffset = .zero
        }
    }

    private func goNext() {
        decisionNotice = nil

        if reduceMotion {
            dragOffset = .zero
            index += 1
            return
        }

        let direction: CGFloat = dragOffset.width < 0 ? -1 : 1
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            dragOffset = .init(width: direction * 520, height: 0)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            dragOffset = .zero
            index += 1
        }
    }
}
