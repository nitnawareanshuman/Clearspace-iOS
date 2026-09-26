import Photos
import UIKit
import AVFoundation

/// PhotoKit may callback more than once, or after cancellation. Resolve exactly once.
private final class RequestGate<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?
    private var result: Result<Value, Error>?
    private var cancellation: (() -> Void)?
    private var timer: DispatchWorkItem?
    func attach(_ continuation: CheckedContinuation<Value, Error>) {
        lock.lock()
        if let result { lock.unlock(); continuation.resume(with: result) }
        else { self.continuation = continuation; lock.unlock() }
    }
    func configure(cancel: @escaping () -> Void) {
        let timeout = DispatchWorkItem { [weak self] in self?.finish(.failure(CleanerError.timedOut)) }
        lock.lock()
        if result != nil { lock.unlock(); cancel(); return }
        cancellation = cancel
        timer = timeout
        lock.unlock()
        DispatchQueue.global().asyncAfter(deadline: .now() + 12, execute: timeout)
    }
    func finish(_ result: Result<Value, Error>) {
        lock.lock()
        guard self.result == nil else { lock.unlock(); return }
        self.result = result
        let continuation = self.continuation
        self.continuation = nil
        let cancel = cancellation
        cancellation = nil
        timer?.cancel()
        timer = nil
        lock.unlock()
        if case .failure = result { cancel?() }
        continuation?.resume(with: result)
    }
}

/// Chunk accounting is protected because callbacks are not guaranteed to share a queue.
private final class ByteCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Int64 = 0
    func add(_ count: Int) { lock.lock(); value += Int64(count); lock.unlock() }
    func total() -> Int64 { lock.lock(); defer { lock.unlock() }; return value }
}

enum PhotoRequests {
    static func image(for asset: PHAsset, side: CGFloat = 256) async throws -> UIImage {
        let gate = RequestGate<UIImage>()
        return try await withTaskCancellationHandler(operation: {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                gate.attach(continuation)
                let options = PHImageRequestOptions()
                options.deliveryMode = .highQualityFormat
                options.resizeMode = .fast
                options.isNetworkAccessAllowed = false
                let request = PHImageManager.default().requestImage(for: asset,
                    targetSize: CGSize(width: side, height: side), contentMode: .aspectFit,
                    options: options) { image, info in
                        if (info?[PHImageResultIsDegradedKey] as? Bool) == true { return }
                        if let image { gate.finish(.success(image)) }
                        else { gate.finish(.failure((info?[PHImageErrorKey] as? Error) ?? CleanerError.unavailable)) }
                    }
                gate.configure { PHImageManager.default().cancelImageRequest(request) }
            }
        }, onCancel: { gate.finish(.failure(CancellationError())) })
    }

    static func playerItem(for asset: PHAsset) async throws -> AVPlayerItem {
        let gate = RequestGate<AVPlayerItem>()
        return try await withTaskCancellationHandler(operation: {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                gate.attach(continuation)
                let options = PHVideoRequestOptions()
                options.isNetworkAccessAllowed = false
                options.deliveryMode = .highQualityFormat
                let manager = PHImageManager.default()
                let request = manager.requestPlayerItem(forVideo: asset, options: options) { item, info in
                    if let item { gate.finish(.success(item)) }
                    else { gate.finish(.failure((info?[PHImageErrorKey] as? Error) ?? CleanerError.unavailable)) }
                }
                gate.configure { manager.cancelImageRequest(request) }
            }
        }, onCancel: { gate.finish(.failure(CancellationError())) })
    }

    static func bytes(for asset: PHAsset) async throws -> Int64 {
        var total: Int64 = 0
        // Counts logical resource bytes, including Live Photo motion and edits, without retaining data.
        let resources = PHAssetResource.assetResources(for: asset)
        guard !resources.isEmpty else { throw CleanerError.unavailable }
        for resource in resources {
            try Task.checkCancellation()
            let gate = RequestGate<Int64>()
            let counter = ByteCounter()
            let amount: Int64 = try await withTaskCancellationHandler(operation: {
                try Task.checkCancellation()
                return try await withCheckedThrowingContinuation { continuation in
                    gate.attach(continuation)
                    let options = PHAssetResourceRequestOptions()
                    options.isNetworkAccessAllowed = false
                    let manager = PHAssetResourceManager.default()
                    let request = manager.requestData(for: resource, options: options,
                        dataReceivedHandler: { counter.add($0.count) }, completionHandler: { error in
                            if let error { gate.finish(.failure(error)) }
                            else { gate.finish(.success(counter.total())) }
                        })
                    gate.configure { manager.cancelDataRequest(request) }
                }
            }, onCancel: { gate.finish(.failure(CancellationError())) })
            total += amount
        }
        return total
    }
}
