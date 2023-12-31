//
//  Timings.swift
//  rem
//
//  Created by Jason McGhee on 12/30/23.
//

import Foundation

class Debouncer {
    private var lastFireTime: DispatchTime = .now()
    private var delay: TimeInterval
    private var workItem: DispatchWorkItem?

    init(delay: TimeInterval) {
        self.delay = delay
    }

    func debounce(action: @escaping () -> Void) {
        workItem?.cancel()
        let deadline = lastFireTime + delay
        workItem = DispatchWorkItem {
            action()
            self.lastFireTime = deadline
        }
        DispatchQueue.main.asyncAfter(deadline: deadline, execute: workItem!)
    }
}

class Throttler {
    private var lastExecution: Date = Date.distantPast
    private let delay: TimeInterval
    private var workItem: DispatchWorkItem?
    private let queue: DispatchQueue

    init(delay: TimeInterval, queue: DispatchQueue = DispatchQueue.main) {
        self.delay = delay
        self.queue = queue
    }

    func throttle(_ block: @escaping () -> Void) {
        workItem?.cancel()

        let now = Date()
        let deadline = lastExecution.addingTimeInterval(delay)
        if now >= deadline {
            lastExecution = now
            block()
        } else {
            workItem = DispatchWorkItem {
                self.lastExecution = Date()
                block()
            }
            let dispatchDelay = DispatchTimeInterval.milliseconds(Int((deadline.timeIntervalSince(now)) * 1000))
            queue.asyncAfter(deadline: .now() + dispatchDelay, execute: workItem!)
        }
    }
}
