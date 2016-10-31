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
    
    var state: State { return _state.value }
    
    let _state: Variable<State>
    
    var isObserved: Bool = false
    
    var avPlayerItem: AVPlayerItem?
    
    public init(state: State = .waiting) {
        _state = Variable(state)
    }
    
    
    open func fetch(_ completion: (_ done: Bool) -> Void) {
        fatalError()
    }
}
