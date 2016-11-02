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


open class PlayerItem: Hashable {
    
    public enum State {
        case waiting, prepareForRequest, requesting, readyForPlay, nowPlaying, rejected
    }
    
    let _state: Variable<State>
    open var state: State {
        set { _state.value = newValue }
        get { return _state.value }
    }
    
    private let uuid = UUID()
    
    public var hashValue: Int { return uuid.hashValue }
    
    var isObserved: Bool = false
    
    var avPlayerItem: AVPlayerItem?
    
    public init(state: State = .waiting) {
        _state = Variable(state)
    }
    
    public static func == (lhs: PlayerItem, rhs: PlayerItem) -> Bool {
        return lhs.uuid == rhs.uuid
    }
    
    open func generateAVPlayerItem(_ completion: (AVPlayerItem?) -> Void) {
        fatalError()
    }
}
