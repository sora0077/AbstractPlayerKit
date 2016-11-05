//
//  Player.swift
//  AbstractPlayerKit
//
//  Created by 林達也 on 2016/10/06.
//  Copyright © 2016年 jp.sora0077. All rights reserved.
//

import Foundation
import AVFoundation
import RxSwift
import RxCocoa


private func partial<A, B, R>(_ f: @escaping (A, B) -> R, _ val: @escaping @autoclosure () -> A) -> (B) -> R {
    return { f(val(), $0) }
}


private func partial<A, B, C, D, R>(
    _ f: @escaping (A, B, C, D) -> R,
    _ a: @escaping @autoclosure () -> A,
    _ c: @escaping @autoclosure () -> C,
    _ d: @escaping @autoclosure () -> D
    ) -> (B) -> R {
    return { f(a(), $0, c(), d()) }
}

public final class Player {

    private let core = AVQueuePlayer()
    
    public fileprivate(set) var nowPlayingItems: [PlayerItem] = []
    
    var workers: [PlayerItem: AnyWorker<AVPlayerItem>] = [:] {
        didSet {
            let workers = self.workers.filter { $1.state == .waiting }.map { ($0, $1) }
            Observable.from(workers)
                .flatMap { (worker: (PlayerItem, AnyWorker<AVPlayerItem>)) in
                    worker.1.run().map { [weak item=worker.0] avPlayerItem in
                        return (item, avPlayerItem)
                    }
                }
                .subscribe(onNext: { (item, avPlayerItem) in
                
                })
                .addDisposableTo(disposeBag)
        }
    }
    
    private let disposeBag = DisposeBag()
    
    public init() {
        core.rx.observeWeakly(AVPlayerStatus.self, #keyPath(AVQueuePlayer.status))
            .subscribe(onNext: { status in
            
            })
            .addDisposableTo(disposeBag)
        core.rx.observeWeakly(AVPlayerItem.self, #keyPath(AVQueuePlayer.currentItem))
            .subscribe(onNext: { currentItem in
                
            })
            .addDisposableTo(disposeBag)
    }
    
    public func canInsert(_ item: PlayerItem, after afterItem: PlayerItem?) -> Bool {
        return true
    }
    
    public func insert(_ item: PlayerItem, after afterItem: PlayerItem?) {
        
    }
}
