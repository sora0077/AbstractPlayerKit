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

final class AnyWorker<R>: Worker {
    typealias Response = R
    
    private let base: _AnyWorkerBase<Response>
    
    init<W: Worker>(_ worker: W) where W.Response == R {
        base = _AnyWorker(base: worker)
    }
    
    var canPop: Bool { return base.canPop }
    func run() -> Observable<Response?> {
        return base.run()
    }
}


enum State {
    case waiting, running, pausing
}

final class WorkerQueue<Response> {
    
    private(set) var state: State = .waiting
    private var _workers: ArraySlice<AnyWorker<Response>> = []
    
    private let queue = DispatchQueue(label: "jp.sora0077.AbstractPlayerKit.WorkerQueue", attributes: [])
    private let disposeBag = DisposeBag()
    
    private let closure: (Response?) -> Bool
    
    init(_ closure: @escaping (Response?) -> Bool) {
        self.closure = closure
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
    
    func add<W: Worker>(_ worker: W) where W.Response == Response {
        queue.async {
            self._workers.append(AnyWorker(worker))
            if self.state == .waiting {
                self.exec()
            }
        }
    }
    
    private func exec() {
        guard let worker = _workers.first else { return }
        
        state = .running
        worker.run()
            .subscribe(onNext: { [weak self, weak wworker=worker] (value) in
                self?.queue.async {
                    if self?.state == .running {
                        self?.state = .waiting
                    }
                    if wworker?.canPop ?? false {
                        _ = self?._workers.popFirst()
                    }
                    
                    if self?.closure(value) ?? false, self?.state != .pausing {
                        self?.exec()
                    }
                }
            })
            .addDisposableTo(disposeBag)
    }
}
