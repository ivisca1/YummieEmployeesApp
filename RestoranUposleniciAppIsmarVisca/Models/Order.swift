//
//  Order.swift
//  RestoranUposleniciAppIsmarVisca
//
//  Created by User on 10. 7. 2023..
//

import Foundation

struct Order {
    var address, email : String
    var ordered, delivered : Bool
    var orderNumber : Int
    var food : [String]
}
