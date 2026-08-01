//
//  String+WordCount.swift
//  Rippple
//
//  Created by Kevin Cador on 03/12/2017.
//  Copyright © Trakt. All rights reserved.
//

import Foundation

extension String {
    var wordCount: Int {
        let inputRange = CFRangeMake(0, utf16.count)
        let flag = UInt(kCFStringTokenizerUnitWord)
        let locale = CFLocaleCopyCurrent()
        let tokenizer = CFStringTokenizerCreate(kCFAllocatorDefault, self as CFString, inputRange, flag, locale)

        var count = 0
        while CFStringTokenizerAdvanceToNextToken(tokenizer) != [] {
            count += 1
        }

        return count
    }

    func tokenize() -> [String] {
        let inputRange = CFRangeMake(0, utf16.count)
        let flag = UInt(kCFStringTokenizerUnitWord)
        let locale = CFLocaleCopyCurrent()
        let tokenizer = CFStringTokenizerCreate(kCFAllocatorDefault, self as CFString, inputRange, flag, locale)
        var tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
        var tokens: [String] = []

        while tokenType != [] {
            let currentTokenRange = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            let substring = substringWithRange(aRange: currentTokenRange)
            tokens.append(substring)
            tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
        }

        return tokens
    }

    func substringWithRange(aRange: CFRange) -> String {
        let nsrange = NSRange(location: aRange.location, length: aRange.length)
        return (self as NSString).substring(with: nsrange)
    }
}
