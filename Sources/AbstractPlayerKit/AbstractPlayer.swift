//
//  AbstractPlayer.swift
//  AbstractPlayer
//
//  Created by 林達也 on 2016/09/28.
//  Copyright © 2016年 jp.sora0077. All rights reserved.
//

import Foundation


public protocol AbstractPlayer {
    
}

open class Player {
    
    var workerQueue: WorkerQueue<URL>!
    
    var urls: ArraySlice<URL> = []

    init() {
        workerQueue = WorkerQueue { [weak self] url in
            guard let url = url else { return }
            self?.urls.append(url)
        }
    }
}
