//
//  ListPredicate.swift
//  books
//
//  Created by Andrew Bennet on 18/01/2018.
//  Copyright © 2018 Andrew Bennet. All rights reserved.
//

import Foundation

class ListPredicate {
    private static let nameFieldName = "name"
    
    static let nameSort = NSSortDescriptor(key: ListPredicate.nameFieldName, ascending: true)
}
