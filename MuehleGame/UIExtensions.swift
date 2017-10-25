//
//  UIExtensions.swift
//  MuehleGame
//
//  Created by Sven Deichsel on 25.10.17.
//  Copyright © 2017 Sven Deichsel. All rights reserved.
//

import UIKit

extension CGRect {
    var center: CGPoint {
        get {
            return CGPoint(x: self.midX, y: self.midY)
        }
        set {
            self.origin = CGPoint(x: newValue.x - self.width / 2, y: newValue.y - self.height / 2)
        }
    }
}

extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        let dx = self.x - other.x
        let dy = self.y - other.y
        let total = dx*dx + dy*dy
        return sqrt(total)
    }
    func offset(dx: CGFloat, dy: CGFloat) -> CGPoint {
        return CGPoint(x: self.x + dx, y: self.y + dy)
    }
}

extension Field {
    var color: UIColor {
        switch self.state {
        case .empty:
            return .clear
        case .filled(color: .white):
            return UIColor.white
        case .filled(color: .black):
            return UIColor.black
        }
    }
}
