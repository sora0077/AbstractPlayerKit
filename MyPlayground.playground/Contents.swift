//: Playground - noun: a place where people can play

import UIKit
@testable import AbstractPlayerKit
import RxSwift
import PlaygroundSupport
import AVFoundation


PlaygroundPage.current.needsIndefiniteExecution = true


final class Track: AbstractPlayerKit.Worker {
    
    typealias Response = URL
    
    var value: URL
    var canPop: Bool = false
    
    init(value: URL) {
        self.value = value
    }
    
    func run() -> Observable<URL?> {
        return Observable.create { [weak self] subscriber in
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                
                let value = self?.value
                if self?.value.path == "/4" {
                    self?.value = URL(string: "http://test4.com/5")!
                } else {
                    self?.canPop = true
                }
                subscriber.onNext(value)
            }
            
            return Disposables.create()
        }
    }
}

final class Playlist: Worker {
    
    typealias Response = URL
    
    let items: [AnyWorker<URL>] = [
        Track(value: URL(string: "http://test.com/1")!),
        Track(value: URL(string: "http://test.com/2")!),
        Track(value: URL(string: "http://test.com/3")!),
        Track(value: URL(string: "http://test.com/4")!),
        Track(value: URL(string: "http://test.com/5")!),
        Track(value: URL(string: "http://test.com/6")!),
        Track(value: URL(string: "http://test.com/7")!),
        Track(value: URL(string: "http://test.com/8")!),
    ].map(AnyWorker.init)
    
    var index: Int = 0
    var readMore: Bool = true
    var canPop: Bool = false
    
    func run() -> Observable<URL?> {
        return Observable<Observable<URL?>>.create { subscriber in
            func exec() {
                
                let items = self.items
                let index = self.index
                if items.count == index {
                    self.canPop = true
                    subscriber.onNext(Observable.just(nil))
                    subscriber.onCompleted()
                    return
                }
                if index == 4, self.readMore {
                    self.readMore = false
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        subscriber.onNext(Observable.just(nil))
                        subscriber.onCompleted()
                    }
                } else {
                    let worker = items[index]
                    self.index += 1
                    subscriber.onNext(worker.run())
                    subscriber.onCompleted()
                }
            }
            exec()
            return Disposables.create()
        }.flatMap { $0 }
    }
}



var items: [URL] = []
let queueingCount = Variable<Int>(0)
let player = QueueController<URL>(queueingCount: queueingCount.asObservable()) { url in
    print(url)
//    items.append(url)
    queueingCount.value = items.count
}

player.add(Playlist())

