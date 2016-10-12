//
//  PlayingQueue.swift
//  AbstractPlayerKit
//
//  Created by 林達也 on 2016/09/28.
//  Copyright © 2016年 jp.sora0077. All rights reserved.
//

import Foundation
import RxSwift


public protocol Worker: class {
    
    associatedtype Response
    
    var canPop: Bool { get }
    
    func run() -> Observable<Response?>
}

private class _AnyWorkerBase<R>: Worker {
    
    typealias Response = R
    
    var canPop: Bool { fatalError() }
    func run() -> Observable<Response?> { fatalError() }
}

private final class _AnyWorker<W: Worker>: _AnyWorkerBase<W.Response> {
    
    let base: W
    
    init(base: W) {
        self.base = base
    }
    
    override var canPop: Bool { return base.canPop }
    override func run() -> Observable<W.Response?> {
        return base.run()
    }
}

final class AnyWorker<R>: Worker, Equatable {
    typealias Response = R
    
    private let id: Int = assignUniqueId()
    
    private let base: _AnyWorkerBase<Response>
    
    init<W: Worker>(_ worker: W) where W.Response == R {
        base = _AnyWorker(base: worker)
    }
    
    static func == <T>(lhs: AnyWorker<T>, rhs: AnyWorker<T>) -> Bool {
        return lhs.id == rhs.id
    }
    
    var canPop: Bool { return base.canPop }
    func run() -> Observable<Response?> {
        return base.run()
    }
}

private var uniqueIdSeed: Int = 0
private func assignUniqueId() -> Int {
    defer {
        uniqueIdSeed += 1
    }
    return uniqueIdSeed
}

enum State {
    case waiting, running, pausing
}

public enum Priority {
    case `default`, high
}

final class WorkerQueue<Response> {
    
    private(set) var state: State = .waiting
    private var highWorkers: ArraySlice<AnyWorker<Response>> = []
    private var workers: ArraySlice<AnyWorker<Response>> = []
    
    private let queue = DispatchQueue(label: "jp.sora0077.AbstractPlayerKit.WorkerQueue", attributes: [])
    private let disposeBag = DisposeBag()
    
    private let next: (Response?) -> Bool
    
    init(_ next: @escaping (Response?) -> Bool) {
        self.next = next
    }
    
    func run() {
        queue.async {
            if self.state != .running {
                self.exec()
            }
        }
    }
    
    func pause() {
        queue.async {
            self.state = .pausing
        }
    }
    
    func add<W: Worker>(_ worker: W, priority: Priority = .default) where W.Response == Response {
        queue.async {
            switch priority {
            case .default:
                self.workers.append(AnyWorker(worker))
            case .high:
                self.highWorkers.append(AnyWorker(worker))
            }
            if self.state == .waiting {
                self.exec()
            }
        }
    }
    
    private func exec() {
        guard let worker = highWorkers.first ?? workers.first else { return }
        
        state = .running
        worker.run()
            .subscribe(onNext: { [weak self, weak wworker=worker] (value) in
                self?.queue.async {
                    defer {
                        if self?.state == .running {
                            self?.state = .waiting
                        }
                    }
                    
                    if let worker = wworker, worker.canPop {
                        if let idx = self?.highWorkers.index(of: worker) {
                            self?.highWorkers.remove(at: idx)
                        } else if let idx = self?.workers.index(of: worker) {
                            self?.workers.remove(at: idx)
                        }
                    }
                    
                    if self?.next(value) ?? false, self?.state != .pausing {
                        self?.exec()
                    }
                }
            })
            .addDisposableTo(disposeBag)
    }
}
