import Foundation

nonisolated final class FileWatcher: @unchecked Sendable {
    private var stream: FSEventStreamRef?
    private let path: String
    private let callback: @Sendable () -> Void
    private var continuation: AsyncStream<Void>.Continuation?

    /// AsyncStream that emits when file changes are detected
    let events: AsyncStream<Void>

    init(path: String, callback: @escaping @Sendable () -> Void) {
        self.path = path
        self.callback = callback
        var cont: AsyncStream<Void>.Continuation?
        self.events = AsyncStream { cont = $0 }
        self.continuation = cont
    }

    func start() {
        let pathsToWatch = [path] as CFArray

        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()

        let flags = UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)

        stream = FSEventStreamCreate(
            nil,
            { _, info, _, _, _, _ in
                guard let info else { return }
                let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()
                watcher.callback()
                watcher.continuation?.yield()
            },
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,
            FSEventStreamCreateFlags(flags)
        )

        if let stream {
            FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
            FSEventStreamStart(stream)
        }
    }

    func stop() {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        stream = nil
        continuation?.finish()
        continuation = nil
    }

    deinit {
        stop()
    }
}
