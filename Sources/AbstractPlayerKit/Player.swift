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
    
    public var playing: Bool { return core.rate != 0 }
    
    private let _priorityHighItems = Variable<[PlayerItem]>([])
    public fileprivate(set) var priorityHighItems: [PlayerItem] = [] {
        didSet {
            updateRequesting()
            _priorityHighItems.value = priorityHighItems
        }
    }
    
    private let _priorityLowItems = Variable<[PlayerItem]>([])
    public fileprivate(set) var priorityLowItems: [PlayerItem] = [] {
        didSet {
            updateRequesting()
            _priorityLowItems.value = priorityLowItems
        }
    }
    
    public private(set) lazy var items: Observable<[PlayerItem]> = Observable
        .combineLatest(self._priorityHighItems.asObservable(), self._priorityLowItems.asObservable()) {
            $0 + $1
        }
    
    fileprivate var requesting: Set<PlayerItem> = []
    
    private var readyToPlayItemsCount: Int {
        func count(_ items: [PlayerItem]) -> Int {
            return items.flatMap { $0.items }.filter {
                switch $0 {
                case .readyToPlay:
                    return true
                default:
                    return false
                }
                }.count
        }
        return count(priorityHighItems) + count(priorityLowItems)
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
    
    private let serialQueue = SerialDispatchQueueScheduler(qos: .default)
    private func updateRequesting() {
        let prefix = 3 + 1 - requesting.count - readyToPlayItemsCount
        guard prefix > 0 else { return }
        let newRequesting = (priorityHighItems + priorityLowItems).lazy
            .filter { $0.state == .prepareForRequest }
            .prefix(prefix)
        requesting.formUnion(Set(newRequesting))
        Observable.from(newRequesting)
            .do(onNext: { $0.state = .requesting })
            .flatMap { (item: PlayerItem) in
                item.fetcher().map { [weak item=item] in (item, $0) }
            }
            .subscribeOn(serialQueue)
            .subscribe(onNext: { [weak self] item, avPlayerItem in
                guard let `self` = self, let item = item else { return }
                defer {
                    item.state = item.didFinishRequest()
                    self.updatePlayerItem()
                    self.updateRequesting()
                }
                if self.requesting.remove(item) != nil, let avPlayerItem = avPlayerItem {
                    item.items.append(.waiting(avPlayerItem))
                }
            })
            .addDisposableTo(disposeBag)
    }
    
    private func updatePlayerItem() {
        func update(to items: [PlayerItem]) -> Bool {
            for item in items {
                guard !item.items.isEmpty else {
                    continue
                }
                func avPlayerItem() -> (Int, AVPlayerItem)? {
                    return item.items.lazy
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
                item.items[index] = .readyToPlay(avPlayerItem)
                return true
            }
            return false
        }
        if update(to: priorityHighItems) || update(to: priorityLowItems) {
            _priorityHighItems.value = priorityHighItems
            _priorityLowItems.value = priorityLowItems
            playIfNeeded()
        }
    }
    
    private func playIfNeeded() {
        func play(from items: [PlayerItem], insertFirst: Bool = false) -> Bool {
            for item in items {
                for (index, playerItem) in item.items.enumerated() {
                    if case .nowPlaying = playerItem { return true }
                    if case .readyToPlay(let avPlayerItem) = playerItem {
                        core.insert(avPlayerItem, after: insertFirst ? core.items().first : nil)
                        if core.status == .readyToPlay {
                            core.play()
                        }
                        item.items[index] = .nowPlaying(avPlayerItem)
                        return true
                    }
                }
            }
            return false
        }
        let alreadyHasNowPlaying = priorityLowItems.contains(where: {
            for item in $0.items {
                if case .nowPlaying = item {
                    return true
                }
            }
            return false
        })
        _ = (!alreadyHasNowPlaying && play(from: priorityHighItems, insertFirst: true)) || play(from: priorityLowItems)
        _priorityHighItems.value = priorityHighItems
        _priorityLowItems.value = priorityLowItems
    }
    
    private func updateNowPlayingItem(currentItem: AVPlayerItem?) {
        func update(from items: [PlayerItem]) -> Bool {
            for item in items {
                for (index, playerItem) in item.items.enumerated() {
                    if let currentItem = currentItem {
                        switch playerItem {
                        case .nowPlaying(let avPlayerItem) where currentItem != avPlayerItem:
                            item.items[index] = .didFinishPlaying
                        case .readyToPlay(let avPlayerItem) where currentItem == avPlayerItem:
                            item.items[index] = .nowPlaying(avPlayerItem)
                            return true
                        default:
                            continue
                        }
                    } else {
                        if case .nowPlaying = playerItem {
                            item.items[index] = .didFinishPlaying
                        }
                    }
                }
            }
            return false
        }
        if !(update(from: priorityHighItems) || update(from: priorityLowItems)) {
            _priorityHighItems.value = priorityHighItems
            _priorityLowItems.value = priorityLowItems
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
    
    public func removeAllItems() {
        core.removeAllItems()
        priorityHighItems.removeAll()
        priorityLowItems.removeAll()
    }
    
    public func remove(_ item: PlayerItem) {
        for itemState in item.items {
            switch itemState {
            case .waiting(let v):
                core.remove(v)
            case .readyToPlay(let v):
                core.remove(v)
            case .nowPlaying(let v):
                core.remove(v)
            default:()
            }
        }
        if let index = priorityHighItems.index(of: item) {
            priorityHighItems.remove(at: index)
        } else if let index = priorityLowItems.index(of: item) {
            priorityLowItems.remove(at: index)
        }
        _ = requesting.remove(item)
    }
    
    public func play() {
        core.play()
    }
    
    public func pause() {
        core.pause()
    }
}
