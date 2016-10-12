//
//  QueueController.swift
//  AbstractPlayer
//
//  Created by 林達也 on 2016/09/28.
//  Copyright © 2016年 jp.sora0077. All rights reserved.
//

import Foundation
import AVKit
import AVFoundation
import RxSwift


public final class QueueController<Response> {
    
    private var workerQueue: WorkerQueue<Response>!
    
    private var queueCondition: Bool {
        return queueingCount <= bufferSize
    }
    
    private let bufferSize: Int
    
    private var queueingCount: Int = 0 {
        didSet {
            if queueCondition {
                workerQueue.run()
            }
        }
    }
    
    private let disposeBag = DisposeBag()
    
    public init(bufferSize: Int = 3, queueingCount: Observable<Int>, call: @escaping (Response) -> Void) {
        self.bufferSize = bufferSize
        
        workerQueue = WorkerQueue { [weak self] item in
            guard let item = item else { return true }
            call(item)
            return self?.queueCondition ?? true
        }
        
        queueingCount.distinctUntilChanged()
            .subscribe(onNext: { [weak self] count in
                self?.queueingCount = count
            })
            .addDisposableTo(disposeBag)
    }
    
    open func add<W: Worker>(_ worker: W, priority: Priority = .default) where W.Response == Response {
        workerQueue.add(worker, priority: priority)
    }
}
