//
//  LinkQueue.swift
//  RunhouseSwift
//
//  Created by ZERO on 2021/5/8.
//  Copyright © 2021 OYFB. All rights reserved.
//

import Foundation

class LinkQueue<T> {
    private class LinkNode<T> {
        var data: T?
        var next: LinkNode<T>?
        
        @available(*, unavailable)
        init() {}
        
        required init(_ data: T? = nil) {
            self.data = data
        }
    }
    
    private var firstNode: LinkNode<T>?
    private var lastNode: LinkNode<T>?
    
    /// 入队
    /// - Parameter data: 数据
    func enqueue(_ data: T) {
        let node = LinkNode(data)
        if firstNode == nil {
            firstNode = node
            lastNode = node
        } else {
            lastNode?.next = node
            lastNode = node
        }
    }
    
    /// 出队
    /// - Returns: 数据
    @discardableResult
    func dequeue() -> T? {
        guard let node = firstNode else { return nil }
        if node.next == nil {
            lastNode = nil
        }
        firstNode = node.next
        return node.data
    }
    
    /// 是否为空
    /// - Returns: Bool
    @discardableResult
    func isEmpty() -> Bool {
        return firstNode == nil
    }
    
    /// 队列中的元素个数
    /// - Returns: Int
    @discardableResult
    func count() -> Int {
        var nextNode = firstNode
        var count = 0
        while nextNode != nil {
            count += 1
            nextNode = nextNode?.next
        }
        return count
    }
    
    /// 返回队列的首位元素
    /// - Returns: 数据
    @discardableResult
    func front() -> T? {
        return firstNode?.data
    }
    
    /// 返回队列的末尾元素
    /// - Returns: 数据
    @discardableResult
    func rear() -> T? {
        return lastNode?.data
    }
    
    func clear() {
        firstNode = nil
        lastNode = nil
    }
}
