//
//  Worker.swift
//  AbstractPlayerKit
//
//  Created by 林達也 on 2016/10/14.
//  Copyright © 2016年 jp.sora0077. All rights reserved.
//

import Foundation
import RxSwift


public enum Priority {
    case `default`, high
}

enum State {
    case waiting, running, pausing
}

public protocol Worker: class {
    
    associatedtype Response
    
    var canPop: Bool { get }
    
    func run() -> Observable<Response?>
}

private class _AnyWorkerBase<R>: Worker {
    
    typealias Response = R
    
    var canPop: Bool { fatalError() }
    func run() -> Observable<Response?> { fatalError() }
}

private final class _AnyWorker<W: Worker>: _AnyWorkerBase<W.Response> {
    
    let base: W
    
    init(base: W) {
        self.base = base
    }
    
    override var canPop: Bool { return base.canPop }
    override func run() -> Observable<W.Response?> {
        return base.run()
    }
}

final class AnyWorker<R>: Worker, Equatable {
    typealias Response = R
    
    private let id: Int = assignUniqueId()
    private let base: _AnyWorkerBase<Response>
    
    var state = State.waiting
    
    init<W: Worker>(_ worker: W) where W.Response == R {
        base = _AnyWorker(base: worker)
    }
    
    static func == <T>(lhs: AnyWorker<T>, rhs: AnyWorker<T>) -> Bool {
        return lhs.id == rhs.id
    }
    
    var canPop: Bool { return base.canPop }
    func run() -> Observable<Response?> {
        return base.run()
    }
}

private var uniqueIdSeed: Int = 0
private func assignUniqueId() -> Int {
    defer {
        uniqueIdSeed += 1
    }
    return uniqueIdSeed
}
