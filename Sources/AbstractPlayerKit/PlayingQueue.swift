//
//  PlayingQueue.swift
//  AbstractPlayerKit
//
//  Created by 林達也 on 2016/09/28.
//  Copyright © 2016年 jp.sora0077. All rights reserved.
//

import Foundation
import RxSwift


protocol Worker: class {
    
    associatedtype Response
    
    var canPop: Bool { get }
    
    func run() -> Observable<Response?>
}


protocol TrackWorker: Worker {
    
    func trackURL() -> Observable<URL?>
}

protocol TrackSequence {
    
    
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
    case waiting, running
}

final class WorkerQueue<Response> {
    
    var state: State = .waiting
    var _workers: ArraySlice<AnyWorker<Response>> = []
    
    private let queue = DispatchQueue(label: "jp.sora0077.AbstractPlayer.WorkerQueue", attributes: [])
    private let disposeBag = DisposeBag()
    
    private let closure: (Response?) -> Void
    
    init(_ closure: @escaping (Response?) -> Void) {
        self.closure = closure
    }
    
    func add<W: Worker>(_ worker: W) where W.Response == Response {
        queue.sync {
            _workers.append(AnyWorker(worker))
            if state == .waiting {
                exec()
            }
        }
    }
    
    private func exec() {
        guard let worker = _workers.first else { return }
        
        state = .running
        worker.run()
            .subscribe(onNext: { [weak self, weak wworker=worker] (value) in
                self?.queue.sync {
                    self?.state = .waiting
                    if wworker?.canPop ?? false {
                        _ = self?._workers.popFirst()
                    }
                    self?.closure(value)
                    self?.exec()
                }
            })
            .addDisposableTo(disposeBag)
    }
}
