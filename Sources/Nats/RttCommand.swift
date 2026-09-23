// Copyright 2024 The NATS Authors
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import NIOConcurrencyHelpers
import NIOCore

internal class RttCommand {
    let startTime = DispatchTime.now()
    let promise: EventLoopPromise<TimeInterval>?
    private let completionLock = NIOLock()
    private var isCompleted = false

    static func makeFrom(channel: Channel?) -> RttCommand {
        RttCommand(promise: channel?.eventLoop.makePromise(of: TimeInterval.self))
    }

    static func withoutPromise() -> RttCommand {
        RttCommand(promise: nil)
    }

    private init(promise: EventLoopPromise<TimeInterval>?) {
        self.promise = promise
    }

    func setRoundTripTime() {
        let now = DispatchTime.now()
        let nanoTime = now.uptimeNanoseconds - startTime.uptimeNanoseconds
        let rtt = TimeInterval(nanoTime) / 1_000_000_000  // Convert nanos to seconds
        complete { $0.succeed(rtt) }
    }

    func fail(_ error: Error) {
        complete { $0.fail(error) }
    }

    func getRoundTripTime() async throws -> TimeInterval {
        try await promise?.futureResult.get() ?? 0
    }

    private func complete(_ completion: (EventLoopPromise<TimeInterval>) -> Void) {
        guard let promise else { return }

        let shouldComplete = completionLock.withLock {
            guard !isCompleted else { return false }
            isCompleted = true
            return true
        }
        guard shouldComplete else { return }
        completion(promise)
    }
}
