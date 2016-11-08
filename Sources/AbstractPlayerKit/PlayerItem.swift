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



open class PlayerItem {
    
    public enum RequestState {
        case prepareForRequest, requesting, done
    }
    
    public enum ItemState {
        case waiting(AVPlayerItem), readyToPlay(AVPlayerItem), nowPlaying(AVPlayerItem), didFinishPlaying
    }
    
    fileprivate let uuid = UUID()
    
    private let _state: Variable<RequestState>
    open internal(set) var state: RequestState {
        set { _state.value = newValue }
        get { return _state.value }
    }
    
    var isObserved: Bool = false
    
    public internal(set) var items: [ItemState] = []
    
    public init(state: RequestState = .prepareForRequest) {
        _state = Variable(state)
    }
    
    open func fetcher() -> Observable<AVPlayerItem?> {
        fatalError()
    }
    
    open func didFinishRequest() -> RequestState {
        return .done
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
