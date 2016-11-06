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

    private let core: AVQueuePlayer
    
    public fileprivate(set) var nowPlayingItems: [PlayerItem] = [] {
        didSet {
            updateRequesting()
        }
    }
    
    public fileprivate(set) var items: [PlayerItem] = [] {
        didSet {
            updateRequesting()
        }
    }
    
    private var requesting: Set<PlayerItem> = []
    
    private let disposeBag = DisposeBag()
    
    public init(queuePlayer: AVQueuePlayer = AVQueuePlayer()) {
        core = queuePlayer
        core.rx.observeWeakly(AVPlayerStatus.self, #keyPath(AVQueuePlayer.status))
            .subscribe(onNext: { [weak self] status in
                if status == .readyToPlay {
                    self?.core.play()
                }
            })
            .addDisposableTo(disposeBag)
        core.rx.observeWeakly(AVPlayerItem.self, #keyPath(AVQueuePlayer.currentItem))
            .subscribe(onNext: { [weak self] currentItem in
                self?.updateNowPlayingItem(currentItem: currentItem)
            })
            .addDisposableTo(disposeBag)
    }
    
    private func updateRequesting() {
        let newRequesting = (nowPlayingItems + items).lazy
            .filter { $0.state == .prepareForRequest }
            .prefix(3 - self.requesting.count)
        self.requesting.formUnion(Set(newRequesting))
        Observable.from(newRequesting)
            .do(onNext: { $0.state = .requesting })
            .flatMap { (item: PlayerItem) in
                item.fetcher().map { [weak item=item] in (item, $0) }
            }
            .subscribeOn(SerialDispatchQueueScheduler(qos: .default))
            .subscribe(onNext: { [weak self] item, avPlayerItem in
                guard let `self` = self, let item = item else { return }
                defer {
                    item.state = item.didFinishRequest()
                    self.updatePlayerItem()
                    self.updateRequesting()
                }
                _ = self.requesting.remove(item)
                if let avPlayerItem = avPlayerItem {
                    item.playerItems.append(.waiting(avPlayerItem))
                }
            })
            .addDisposableTo(disposeBag)
    }
    
    private func updatePlayerItem() {
        func update(to items: [PlayerItem]) {
            for item in items {
                guard !item.playerItems.isEmpty else {
                    return
                }
                func avPlayerItem() -> (Int, AVPlayerItem)? {
                    return item.playerItems.lazy
                        .enumerated()
                        .flatMap { (index, playerItem) in
                            switch playerItem {
                            case .waiting(let avPlayerItem):
                                return (index, avPlayerItem)
                            default:
                                return nil
                            }
                        }.first
                }
                
                guard let (index, avPlayerItem) = avPlayerItem() else { return }
                item.playerItems[index] = .readyToPlay(avPlayerItem)
            }
        }
        
        update(to: nowPlayingItems)
        update(to: items)
    }
    
    private func playIfNeeded() {
        func play(from items: [PlayerItem]) -> Bool {
            for item in items {
                for (index, playerItem) in item.playerItems.enumerated() {
                    if case .nowPlaying = playerItem { return true }
                    if case .readyToPlay(let avPlayerItem) = playerItem {
                        core.insert(avPlayerItem, after: nil)
                        item.playerItems[index] = .nowPlaying(avPlayerItem)
                        return true
                    }
                }
            }
            return false
        }
        _ = play(from: nowPlayingItems) || play(from: items)
    }
    
    private func updateNowPlayingItem(currentItem: AVPlayerItem?) {
        func update(from items: [PlayerItem]) -> Bool {
            for item in items {
                for (index, playerItem) in item.playerItems.enumerated() {
                    if let currentItem = currentItem {
                        switch playerItem {
                        case .nowPlaying(let avPlayerItem) where currentItem != avPlayerItem:
                            item.playerItems[index] = .didFinishPlaying(avPlayerItem)
                        case .readyToPlay(let avPlayerItem) where currentItem == avPlayerItem:
                            item.playerItems[index] = .nowPlaying(avPlayerItem)
                            return true
                        default:
                            continue
                        }
                    } else {
                        if case .nowPlaying(let avPlayerItem) = playerItem {
                            item.playerItems[index] = .didFinishPlaying(avPlayerItem)
                        }
                    }
                }
            }
            return false
        }
        guard update(from: nowPlayingItems) || update(from: items) else {
            playIfNeeded()
            return
        }
    }
}


extension Player {
    public func insert(_ item: PlayerItem) {
        nowPlayingItems.append(item)
    }
    
    public func insert(_ item: PlayerItem, after afterItem: PlayerItem?) {
        if let afterItem = afterItem, let index = items.index(of: afterItem) {
            items.insert(item, at: index + 1)
        } else {
            items.append(item)
        }
    }
}
