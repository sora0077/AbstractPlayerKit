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
        case waiting, requesting, readyForPlay, nowPlaying
    }
    
    var state: State = .waiting
    
    var avPlayerItem: AVPlayerItem?
    
    open func requestingFinished() {
        
    }
}
