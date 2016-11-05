//
//  PlayerItem.swift
//  AbstractPlayerKit
//
//  Created by 林達也 on 2016/10/30.
//  Copyright © 2016年 jp.sora0077. All rights reserved.
//

import Foundation
import AVFoundation
import RxSwift


public enum State {
    case prepareForRequest, requesting, readyForPlay(isRequestFinished: Bool), nextPlaying, nowPlaying, waiting, rejected
}

open class PlayerItem {
    
    fileprivate let uuid = UUID()
    
    let _state: Variable<State>
    open var state: State {
        set { _state.value = newValue }
        get { return _state.value }
    }
    
    var isObserved: Bool = false
    
    var items: [AVPlayerItem] = []
    
    public init(state: State = .prepareForRequest) {
        _state = Variable(state)
    }
    
    func worker() -> AnyWorker<AVPlayerItem> {
        fatalError()
    }
    
    open func generateAVPlayerItem(_ completion: @escaping (AVPlayerItem) -> Void) {
        fatalError()
    }
}

extension PlayerItem: Hashable {
    public var hashValue: Int { return uuid.hashValue }
    
    public static func == (lhs: PlayerItem, rhs: PlayerItem) -> Bool {
        return lhs.uuid == rhs.uuid
    }
}

extension State: Equatable {
    public static func == (lhs: State, rhs: State) -> Bool {
        switch (lhs, rhs) {
        case (.prepareForRequest, .prepareForRequest),
             (.requesting, .requesting),
             (.nowPlaying, .nowPlaying),
             (.waiting, .waiting),
             (.rejected, .rejected):
            return true
        case (.readyForPlay(let lhs), .readyForPlay(let rhs)):
            return lhs == rhs
        default:
            return false
        }
    }
}
