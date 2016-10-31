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


func partial<A, B, R>(_ f: @escaping (A, B) -> R, _ val: @escaping @autoclosure () -> A) -> (B) -> R {
    return { f(val(), $0) }
}


func partial<A, B, C, D, R>(
    _ f: @escaping (A, B, C, D) -> R,
    _ a: @escaping @autoclosure () -> A,
    _ c: @escaping @autoclosure () -> C,
    _ d: @escaping @autoclosure () -> D
    ) -> (B) -> R {
    return { f(a(), $0, c(), d()) }
}


public final class Player<Item: PlayerItem> {
    
    fileprivate let core = _Player()
    
    private let disposeBag = DisposeBag()
    
    var currentItem: PlayerItem?
    
    public fileprivate(set) var items: [Item] = [] {
        didSet {
            items
                .filter { !$0.isObserved }
                .forEach {
                    $0._state.asObservable()
                        .subscribe(onNext: { [weak self, weak item=$0] state in
                            guard let `self` = self, let item = item else { return }
                            switch state {
                            case .prepareForRequest:
                                self.updateRequestQueue()
                            case .requesting:()
                            case .readyForPlay:
                                if let index = self.requesting.index(where: { $0 === item }) {
                                    self.requesting.remove(at: index)
                                    self.updateRequestQueue()
                                }
                            case .nowPlaying:
                                break
                            case .rejected:
                                if let index = self.items.index(where: { $0 === item }) {
                                    self.items.remove(at: index)
                                }
                                if let index = self.requesting.index(where: { $0 === item }) {
                                    self.requesting.remove(at: index)
                                }
                            case .waiting:()
                            }
                        })
                        .addDisposableTo(disposeBag)
                    $0.isObserved = true
                }
            
        }
    }
    
    private var requesting: ArraySlice<Item> = [] {
        didSet {
            for item in requesting {
                if item._state.value == .waiting {
                    item._state.value = .prepareForRequest
                }
                if item._state.value == .prepareForRequest {
                    item._state.value = .requesting
                    item.fetch { [weak item=item] done in
                        item?._state.value = done ? .readyForPlay : .prepareForRequest
                    }
                }
            }
        }
    }
    
    private let requestCount: Int
    
    public init(requestCount: Int = 3) {
        self.requestCount = requestCount
        core.delegate = self
    }
    
    private func updateRequestQueue() {
        requesting = requesting + items
            .filter { $0.state == .waiting }
            .prefix(requestCount - requesting.count)
    }
}

public extension Player {
    func play() { core.play() }
    
    func pause() { core.pause() }
    
    func advanceToNextItem() { core.advanceToNextItem() }
    
    func canInsert(_ item: Item, after afterItem: Item?) -> Bool {
        if let item = item.avPlayerItem {
            return core.canInsert(item, after: afterItem?.avPlayerItem)
        }
        return true
    }
    
    func insert(_ item: Item, after afterItem: Item?) {
        if let item = item.avPlayerItem {
            core.insert(item, after: afterItem?.avPlayerItem)
        }
        if let index = items.index(where: { $0 === afterItem }) {
            items.insert(item, at: index)
        } else {
            items.append(item)
        }
    }
    
    func remove(_ item: Item) {
        if let item = item.avPlayerItem {
            core.remove(item)
        }
        if let index = items.index(where: { $0 === item }) {
            items.remove(at: index)
        }
    }
    
    func removeAllItems() {
        core.removeAllItems()
        items.removeAll()
    }
}

extension Player: CoreDelegate {
    
    func updateCurrentItem(_ item: AVPlayerItem?) {
        if let item = item {
            if currentItem?.avPlayerItem !== item {
                if let index = items.index(where: { $0 === currentItem }) {
                    items.remove(at: index)
                }
                currentItem = items.lazy.filter { $0.avPlayerItem === item }.first
            }
        } else {
            currentItem = nil
        }
    }
}



private extension AVQueuePlayer {
    struct KeyPath {
        static let status = #keyPath(AVQueuePlayer.status)
        static let currentItem = #keyPath(AVQueuePlayer.currentItem)
        
        private init() {}
    }
}


private protocol CoreDelegate: class {
    
    func updateCurrentItem(_ item: AVPlayerItem?)
}

private final class _Player: NSObject {
    private let core = AVQueuePlayer()
    
    weak var delegate: CoreDelegate?
    
    var currentItem: AVPlayerItem? { return core.currentItem }
    
    var items: [AVPlayerItem] { return core.items() }
    
    override init() {
        super.init()
        
        let keyPath = [AVQueuePlayer.KeyPath.currentItem, AVQueuePlayer.KeyPath.currentItem]
        keyPath.forEach(partial(core.addObserver, self, [.new], nil))
    }
    
    deinit {
        let keyPath = [AVQueuePlayer.KeyPath.currentItem, AVQueuePlayer.KeyPath.currentItem]
        keyPath.forEach(partial(core.removeObserver, self))
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath else { return }
        
        switch keyPath {
        case AVQueuePlayer.KeyPath.status:
            break
        case AVQueuePlayer.KeyPath.currentItem:
            delegate?.updateCurrentItem(core.currentItem)
        default:()
        }
    }
    
    func play() { core.play() }
    
    func pause() { core.pause() }
    
    func advanceToNextItem() { core.advanceToNextItem() }
    
    func canInsert(_ item: AVPlayerItem, after afterItem: AVPlayerItem?) -> Bool { return core.canInsert(item, after: afterItem) }
    
    func insert(_ item: AVPlayerItem, after afterItem: AVPlayerItem?) { core.insert(item, after: afterItem) }
    
    func remove(_ item: AVPlayerItem) { core.remove(item) }
    
    func removeAllItems() { core.removeAllItems() }
}
