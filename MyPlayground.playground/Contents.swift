//: Playground - noun: a place where people can play

import UIKit
@testable import AbstractPlayerKit
import RxSwift
import PlaygroundSupport
import AVFoundation


PlaygroundPage.current.needsIndefiniteExecution = true


final class Worker: AbstractPlayerKit.Worker {
    
    typealias Response = URL
    
    var value: URL
    var canPop: Bool = false
    
    init(value: URL) {
        self.value = value
    }
    
    func run() -> Observable<URL?> {
        return Observable.create { [weak self] subscriber in
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                
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

var items: [URL] = []
let queueingCount = Variable<Int>(0)
let player = QueueController<URL>(queueingCount: queueingCount.asObservable()) { url in
    print(url)
    items.append(url)
    queueingCount.value = items.count
}

player.add(Worker(value: URL(string: "http://test.com/1")!))
player.add(Worker(value: URL(string: "http://test.com/2")!))
player.add(Worker(value: URL(string: "http://test.com/3")!))
player.add(Worker(value: URL(string: "http://test.com/4")!))
player.add(Worker(value: URL(string: "http://test.com/5")!))
player.add(Worker(value: URL(string: "http://test.com/6")!))
player.add(Worker(value: URL(string: "http://test.com/7")!))
player.add(Worker(value: URL(string: "http://test.com/8")!))
player.add(Worker(value: URL(string: "http://test.com/9")!))


