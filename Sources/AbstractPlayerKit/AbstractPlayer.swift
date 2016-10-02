//
//  AbstractPlayer.swift
//  AbstractPlayer
//
//  Created by 林達也 on 2016/09/28.
//  Copyright © 2016年 jp.sora0077. All rights reserved.
//

import Foundation
import AVKit
import AVFoundation


public protocol TrackWorker: Worker {
    typealias Response = URL
}


public final class QueueController {
    
    private var workerQueue: WorkerQueue<URL>!
    
    private var queueCondition: Bool {
        return queueingCount() < bufferSize
    }
    
    private var urls: ArraySlice<URL> = [] {
        didSet {
            if queueCondition {
                workerQueue.run()
                if let url = urls.popFirst() {
                    call(url)
                }
            } else {
                workerQueue.pause()
            }
        }
    }
    
    private let bufferSize: Int
    private let queueingCount: () -> Int
    private let call: (URL) -> Void
    
    public init(bufferSize: Int = 3, queueingCount: @autoclosure @escaping () -> Int, call: @escaping (URL) -> Void) {
        self.bufferSize = bufferSize
        self.queueingCount = queueingCount
        self.call = call
        
        workerQueue = WorkerQueue { [weak self] url in
            guard let url = url else { return true }
            self?.urls.append(url)
            return self?.queueCondition ?? true
        }
    }
    
    open func add<T: TrackWorker>(_ worker: T) {
        workerQueue.add(worker)
    }
}
