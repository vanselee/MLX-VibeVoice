import Foundation

enum GenerationService {
    static func start(script: Script) {
        resetSegments(for: script)
        resume(script: script)
    }

    static func resume(script: Script) {
        let orderedSegments = script.segments.sorted { $0.order < $1.order }
        guard !orderedSegments.isEmpty else {
            script.status = .ready
            script.updatedAt = .now
            return
        }

        if script.status == .completed {
            orderedSegments.forEach { $0.status = .pending }
        }

        if let nextSegment = orderedSegments.first(where: { $0.status == .pending }) {
            nextSegment.status = .generating
            script.status = .generating
        } else if orderedSegments.allSatisfy({ $0.status == .completed }) {
            script.status = .completed
        } else {
            script.status = .ready
        }
        script.updatedAt = .now
    }

    static func pause(script: Script) {
        for segment in script.segments where segment.status == .generating {
            segment.status = .pending
        }
        script.status = .ready
        script.updatedAt = .now
    }

    static func cancel(script: Script) {
        for segment in script.segments {
            segment.status = .pending
        }
        script.status = .ready
        script.updatedAt = .now
    }

    static func retryFailedSegments(script: Script) {
        for segment in script.segments where segment.status == .failed {
            segment.status = .pending
        }
        resume(script: script)
    }

    static func retry(segment: ScriptSegment, in script: Script) {
        segment.status = .pending
        resume(script: script)
    }

    static func advanceOneTick(in scripts: [Script]) {
        guard let script = scripts
            .filter({ $0.status == .generating })
            .sorted(by: { $0.updatedAt < $1.updatedAt })
            .first
        else {
            return
        }

        let orderedSegments = script.segments.sorted { $0.order < $1.order }
        guard !orderedSegments.isEmpty else {
            script.status = .ready
            script.updatedAt = .now
            return
        }

        if let generatingSegment = orderedSegments.first(where: { $0.status == .generating }) {
            generatingSegment.status = .completed
        }

        if let nextSegment = orderedSegments.first(where: { $0.status == .pending }) {
            nextSegment.status = .generating
        } else if orderedSegments.allSatisfy({ $0.status == .completed }) {
            script.status = .completed
        } else if orderedSegments.contains(where: { $0.status == .failed }) {
            script.status = .failed
        } else {
            script.status = .ready
        }
        script.updatedAt = .now
    }

    private static func resetSegments(for script: Script) {
        for segment in script.segments {
            segment.status = .pending
        }
    }
}
