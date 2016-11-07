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


public final class Player: NSObject {
    
    fileprivate let core: AVQueuePlayer
    
    public fileprivate(set) var priorityHighItems: [PlayerItem] = [] {
        didSet {
            updateRequesting()
        }
    }
    
    public fileprivate(set) var priorityLowItems: [PlayerItem] = [] {
        didSet {
            updateRequesting()
        }
    }
    
    private var requesting: Set<PlayerItem> = []
    
    private var readyToPlayItemsCount: Int {
        return (priorityHighItems + priorityLowItems).flatMap { $0.playerItems }.filter {
            switch $0 {
            case .readyToPlay:
                return true
            default:
                return false
            }
            }.count
    }
    
    private let disposeBag = DisposeBag()
    
    public init(queuePlayer: AVQueuePlayer = AVQueuePlayer()) {
        core = queuePlayer
        super.init()
        core.addObserver(self, forKeyPath: #keyPath(AVQueuePlayer.status), options: .new, context: nil)
        core.addObserver(self, forKeyPath: #keyPath(AVQueuePlayer.currentItem), options: .new, context: nil)
    }
    
    deinit {
        core.removeObserver(self, forKeyPath: #keyPath(AVQueuePlayer.status))
        core.removeObserver(self, forKeyPath: #keyPath(AVQueuePlayer.currentItem))
    }
    
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath else { return }
        switch keyPath {
        case #keyPath(AVQueuePlayer.status) where core.status == .readyToPlay:
            core.play()
        case #keyPath(AVQueuePlayer.currentItem):
            updateNowPlayingItem(currentItem: core.currentItem)
            if requesting.isEmpty {
                updateRequesting()
            }
        default:()
        }
    }
    
    private func updateRequesting() {
        let prefix = 3 + 1 - requesting.count - readyToPlayItemsCount
        guard prefix > 0 else { return }
        let newRequesting = (priorityHighItems + priorityLowItems).lazy
            .filter { $0.state == .prepareForRequest }
            .prefix(prefix)
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
        func update(to items: [PlayerItem]) -> Bool {
            for item in items {
                guard !item.playerItems.isEmpty else {
                    continue
                }
                func avPlayerItem() -> (Int, AVPlayerItem)? {
                    return item.playerItems.lazy
                        .enumerated()
                        .filter {
                            if case .waiting = $1 {
                                return true
                            }
                            return false
                        }
                        .flatMap { (index, playerItem) in
                            switch playerItem {
                            case .waiting(let avPlayerItem):
                                return (index, avPlayerItem)
                            default:
                                return nil
                            }
                        }.first
                }
                
                guard let (index, avPlayerItem) = avPlayerItem() else { continue }
                item.playerItems[index] = .readyToPlay(avPlayerItem)
                return true
            }
            return false
        }
        if update(to: priorityHighItems) || update(to: priorityLowItems) {
            playIfNeeded()
        }
    }
    
    private func playIfNeeded() {
        func play(from items: [PlayerItem]) -> Bool {
            for item in items {
                for (index, playerItem) in item.playerItems.enumerated() {
                    if case .nowPlaying = playerItem { return true }
                    if case .readyToPlay(let avPlayerItem) = playerItem {
                        core.insert(avPlayerItem, after: nil)
                        if core.status == .readyToPlay {
                            core.play()
                        }
                        item.playerItems[index] = .nowPlaying(avPlayerItem)
                        return true
                    }
                }
            }
            return false
        }
        _ = play(from: priorityHighItems) || play(from: priorityLowItems)
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
        if !(update(from: priorityHighItems) || update(from: priorityLowItems)) {
            playIfNeeded()
        }
    }
}


extension Player {
    public func insert(inPriorityHigh item: PlayerItem) {
        priorityHighItems.append(item)
    }
    
    public func insert(_ item: PlayerItem, after afterItem: PlayerItem?) {
        if let afterItem = afterItem, let index = priorityLowItems.index(of: afterItem) {
            priorityLowItems.insert(item, at: index + 1)
        } else {
            priorityLowItems.append(item)
        }
    }
    
    public func advanceToNextItem() {
        core.advanceToNextItem()
    }
    
    public func removeAll() {
        core.removeAllItems()
        priorityHighItems.removeAll()
        priorityLowItems.removeAll()
    }
    
    public func play() {
        core.play()
    }
    
    public func pause() {
        core.pause()
    }
}
