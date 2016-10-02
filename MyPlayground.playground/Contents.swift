//: Playground - noun: a place where people can play

import UIKit
@testable import AbstractPlayerKit
import RxSwift
import PlaygroundSupport


PlaygroundPage.current.needsIndefiniteExecution = true


final class Worker: AbstractPlayerKit.Worker {
    
    typealias Response = URL
    
    var value: Response
    var canPop: Bool = false
    
    init(value: Response) {
        self.value = value
    }
    
    func run() -> Observable<Response?> {
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


let queue = WorkerQueue<URL> { res in
    print("any ", res)
}
queue.add(Worker(value: URL(string: "http://test.com/1")!))
queue.add(Worker(value: URL(string: "http://test.com/2")!))
queue.add(Worker(value: URL(string: "http://test.com/3")!))
queue.add(Worker(value: URL(string: "http://test.com/4")!))
queue.add(Worker(value: URL(string: "http://test.com/5")!))
queue.add(Worker(value: URL(string: "http://test.com/6")!))
queue.add(Worker(value: URL(string: "http://test.com/7")!))
queue.add(Worker(value: URL(string: "http://test.com/8")!))
queue.add(Worker(value: URL(string: "http://test.com/9")!))
