//
//  PlayingQueue.swift
//  AbstractPlayerKit
//
//  Created by 林達也 on 2016/09/28.
//  Copyright © 2016年 jp.sora0077. All rights reserved.
//

import Foundation
import RxSwift


final class WorkerQueue<Response> {
    
    private(set) var state: State = .waiting
    private var highWorkers: ArraySlice<AnyWorker<Response>> = []
    private var workers: ArraySlice<AnyWorker<Response>> = []
    
    private let queue = DispatchQueue(label: "jp.sora0077.AbstractPlayerKit.WorkerQueue")
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
    
    func remove(at index: Int, priority: Priority = .default) {
        func removeWorker(from array: inout ArraySlice<AnyWorker<Response>>) {
            if let worker = array[safe: index], worker.state == .waiting {
                array.remove(at: index)
            }
        }
        queue.async {
            switch priority {
            case .default:
                removeWorker(from: &self.workers)
            case .high:
                removeWorker(from: &self.highWorkers)
            }
        }
    }
    
    func removeAll() {
        queue.async {
            self.highWorkers.removeAll()
            self.workers.removeAll()
        }
    }
    
    private func exec() {
        highWorkers = ArraySlice(highWorkers.filter { !$0.canPop })
        workers = ArraySlice(workers.filter { !$0.canPop })
        guard let worker = highWorkers.first ?? workers.first else { return }
        
        (worker.state, state) = (.running, .running)
        worker.run()
            .subscribe(onNext: { [weak self, weak wworker=worker] (value) in
                guard let `self` = self else { return }
                self.queue.async {
                    defer {
                        if self.state == .running {
                            self.state = .waiting
                        }
                    }
                    
                    if let worker = wworker, worker.canPop {
                        if let idx = self.highWorkers.index(of: worker) {
                            self.highWorkers.remove(at: idx)
                        } else if let idx = self.workers.index(of: worker) {
                            self.workers.remove(at: idx)
                        }
                    }
                    
                    if self.next(value), self.state != .pausing {
                        self.exec()
                    }
                }
            })
            .addDisposableTo(disposeBag)
    }
}

extension ArraySlice {
    fileprivate subscript (safe index: Int) -> Element? {
        return count > index ? self[index] : nil
    }
}
