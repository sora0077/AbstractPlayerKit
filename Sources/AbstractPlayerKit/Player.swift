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
    
    fileprivate let core: _Player
    
    private let disposeBag = DisposeBag()
    
    public var currentItem: PlayerItem?
    
    public fileprivate(set) var items: [Item] = [] {
        didSet {
            items
                .lazy
                .filter { !$0.isObserved }
                .forEach {
                    $0.isObserved = true
                    $0._state.asObservable()
                        .distinctUntilChanged()
                        .observeOn(SerialDispatchQueueScheduler(qos: .default))
                        .subscribe(onNext: { [weak self, weak item=$0] state in
                            guard let `self` = self, let item = item else { return }
                            self.update(item, in: state)
                        })
                        .addDisposableTo(disposeBag)
                }
            
        }
    }
    
    fileprivate var requesting: ArraySlice<Item> = [] {
        didSet {
            for item in Set(requesting).subtracting(oldValue) {
                if item.state == .waiting {
                    item.state = .prepareForRequest
                }
                if item.state == .prepareForRequest {
                    item.state = .requesting
                }
            }
        }
    }
    
    private let requestLimit: Int
    
    public init(core: AVQueuePlayer = AVQueuePlayer(), requestLimit: Int = 3) {
        self.core = _Player(core: core)
        self.requestLimit = requestLimit
        self.core.delegate = self
    }
    
    private func update(_ item: Item, in state: Item.State) {
        switch state {
        case .prepareForRequest:
            updateRequestQueue()
        case .readyForPlay:
            if let index = requesting.index(of: item) {
                requesting.remove(at: index)
                updateRequestQueue()
            }
        case .rejected:
            if let index = items.index(of: item) {
                items.remove(at: index)
            }
            if let index = requesting.index(of: item) {
                requesting.remove(at: index)
                updateRequestQueue()
            }
        case .waiting:()
        case .requesting:()
        case .nowPlaying:()
        }
    }
    
    private func updateRequestQueue() {
        requesting = requesting + items
            .filter { $0.state == .waiting }
            .prefix(requestLimit - requesting.count)
    }
    
    private func updateNowPlaying() {
        guard let item = items.first, let avPlayerItem = item.avPlayerItem, item.state == .readyForPlay else {
            return
        }
        item.state = .nowPlaying
        avPlayerItem.asset.loadValuesAsynchronously(forKeys: ["duration"]) { [weak self] in
            self?.core.insert(avPlayerItem, after: nil)
        }
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
    
    func insert(atFirst item: Item) {
        items.insert(item, at: 0)
    }
    
    func insert(_ item: Item, after afterItem: Item?) {
        if let index = items.index(of: item) {
            items.insert(item, at: index + 1)
        } else {
            items.append(item)
        }
    }
    
    func remove(_ item: Item) {
        if let item = item.avPlayerItem {
            core.remove(item)
        }
        if let index = items.index(of: item) {
            items.remove(at: index)
        }
        if let index = requesting.index(of: item) {
            requesting.remove(at: index)
        }
    }
    
    func removeAllItems() {
        core.removeAllItems()
        items.removeAll()
        requesting.removeAll()
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
    private let core: AVQueuePlayer
    
    weak var delegate: CoreDelegate?
    
    var currentItem: AVPlayerItem? { return core.currentItem }
    
    var items: [AVPlayerItem] { return core.items() }
    
    init(core: AVQueuePlayer) {
        self.core = core
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
