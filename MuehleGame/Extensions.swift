//
//  Other.swift
//  MuehleKI
//
//  Created by Sven Deichsel on 10.10.17.
//  Copyright © 2017 Sven Deichsel. All rights reserved.
//

import Foundation

extension Array {
    func only<T: Equatable>(same: (Element) throws -> T) rethrows -> Bool {
        var main: T? = nil
        for e in self {
            if let s = main {
                if try s != same(e) {
                    return false
                }
            } else {
                main = try same(e)
            }
        }
        return true
    }
    func only(matching: (Element) throws -> Bool) rethrows -> Bool {
        for e in self {
            guard try matching(e) else {
                return false
            }
        }
        return true
    }
}

extension Int {
    public static func random(limit: Int) -> Int {
        return Int(arc4random_uniform(UInt32(limit)))
    }
}
extension Array {
    public func isValidIndex(_ index: Int) -> Bool {
        return self.indices.contains(index)
    }
    public func element(at index: Int) -> Element? {
        guard self.isValidIndex(index) else {
            return nil
        }
        return self[index]
    }
    public func random() -> (index: Int, element: Element)? {
        let index = Int.random(limit: self.count)
        guard self.isValidIndex(index) else {
            return nil
        }
        return (index,self[index])
    }
    public func last(n: Int) -> ArraySlice<Element> {
        guard self.count >= n else {
            return self[...]
        }
        return self[(self.count - n)...]
    }
    public func first(_ n: Int) -> Array<Element> {
        var arr: [Element] = []
        for i in 0..<n {
            if i < self.count {
                arr.append(self[i])
            } else {
                break
            }
        }
        return arr
    }
    public func count(where predicate: (Element) throws -> Bool) rethrows -> Int {
        var c = 0
        for e in self {
            if try predicate(e) {
                c += 1
            }
        }
        return c
    }
}

extension Array where Element == Field {
    func asMuehleFields() -> [Game.MuehleField] {
        return self.map({ return Game.MuehleField(field: $0) })
    }
}

extension Array where Element == Field.State {
    func toNetworkInput(ownColor: Game.Color) -> [Float] {
        return self.map({
            switch $0 {
            case .empty:
                return 0.0
            case .filled(color: let c):
                if c == ownColor {
                    return 1.0
                } else {
                    return -1.0
                }
            }
        })
    }
}

extension Array where Element: Equatable {
    mutating func remove(_ e: Element) {
        for i in self.indices.reversed() {
            if self[i] == e {
                self.remove(at: i)
            }
        }
    }
}

extension Array where Element: Comparable {
    enum ElementType {
        case max, min
    }
    func index(of type: ElementType) -> Int? {
        var i: Int? = nil
        let compare: (Element,Element) -> Bool
        switch type {
        case .max:
            compare = { return $0 > $1 }
        case .min:
            compare = { return $0 < $1 }
        }
        for index in self.indices {
            if let j = i {
                if compare(self[index],self[j]) {
                    i = index
                }
            } else {
                i = index
            }
        }
        return i
    }
}
