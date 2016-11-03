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
    
    public enum State {
        case waiting, prepareForRequest, requesting, readyForPlay, nowPlaying, rejected
    }
    
    fileprivate let uuid = UUID()
    
    let _state: Variable<State>
    open var state: State {
        set { _state.value = newValue }
        get { return _state.value }
    }
    
    var isObserved: Bool = false
    
    var avPlayerItem: AVPlayerItem?
    
    public init(state: State = .waiting) {
        _state = Variable(state)
    }
    
    open func generateAVPlayerItem(_ completion: (AVPlayerItem?) -> Void) {
        fatalError()
    }
}

extension PlayerItem: Hashable {
    public var hashValue: Int { return uuid.hashValue }
    
    public static func == (lhs: PlayerItem, rhs: PlayerItem) -> Bool {
        return lhs.uuid == rhs.uuid
    }
}
