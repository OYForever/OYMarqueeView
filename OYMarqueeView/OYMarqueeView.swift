//
//  OYMarqueeView.swift
//  OYMarqueeView
//
//  Created by ZERO on 2021/5/8.
//  Copyright © 2021 OYFB. All rights reserved.
//

import UIKit

// MARK: - OYMarqueeViewItem
open class OYMarqueeViewItem: UIView {
    private(set) var reuseIdentifier: String
    
    public init() {
        self.reuseIdentifier = ""
        super.init(frame: .zero)
    }
    
    required public init(reuseIdentifier: String) {
        self.reuseIdentifier = reuseIdentifier
        super.init(frame: .zero)
    }
    
    @available(*, unavailable)
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - MarqueeViewDataSource
public protocol OYMarqueeViewDataSource: AnyObject {
    func numberOfItems(in marqueeView: OYMarqueeView) -> Int
    func marqueeView(_ marqueeView: OYMarqueeView, itemForIndexAt index: Int) -> OYMarqueeViewItem
    func marqueeView(_ marqueeView: OYMarqueeView, itemSizeForIndexAt index: Int) -> CGSize
}

public enum ScrollDirection {
    case horizontal
    case vertical
}

public enum ScrollOrientation {
    case forward
    case backward
}

public final class OYMarqueeView: UIView {
    
    // MARK: - Properties
    public weak var dataSourse: OYMarqueeViewDataSource?
    
    private(set) var scrollDirection: ScrollDirection
    public var scrollOrientation: ScrollOrientation = .forward
    
    /// 每秒移动的像素点
    public var pixelsPerSecond: CGFloat = 50 {
        didSet {
            updateSpeed()
        }
    }
    
    private var speed: CGFloat = 1
    public var space: CGFloat = 30
    private var offset: CGFloat = 100
    
    private var currentIndex = 0
    private var itemCount = 0
    private var oldFrame: CGRect?
    
    private var visibleItems: [OYMarqueeViewItem] = []
    private var reuseCache: [String: LinkQueue<OYMarqueeViewItem>] = [:]
    private var classCache: [String: AnyClass] = [:]
    private var sizeCache: [Int: CGSize] = [:]
    
    private var displayLink: CADisplayLink?
    
    // MARK: - Lifecycle
    public init(frame: CGRect = .zero, scrollDirection: ScrollDirection = .horizontal) {
        self.scrollDirection = scrollDirection
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        self.scrollDirection = .horizontal
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        clipsToBounds = true
        setupDisplayLink()
    }
    
    deinit {
        displayLink?.invalidate()
    }
    
    // MARK: - Public Methods
    public func register(_ itemClass: AnyClass, forItemReuseIdentifier identifier: String) {
        classCache[identifier] = itemClass
    }
    
    public func dequeueReusableItem(withIdentifier identifier: String) -> OYMarqueeViewItem {
        if let item = reuseCache[identifier]?.dequeue() {
            return item
        }
        
        guard let itemClass = classCache[identifier] as? OYMarqueeViewItem.Type else {
            fatalError("未注册identifier: \(identifier)对应的类")
        }
        return itemClass.init(reuseIdentifier: identifier)
    }
    
    public func reloadData() {
        invalidateDisplayLink()
        removeAllItems()
        clearCache()
        
        guard let dataSourse = dataSourse, dataSourse.numberOfItems(in: self) > 0 else { return }
        
        itemCount = dataSourse.numberOfItems(in: self)
        currentIndex = 0
        
        layoutInitialItems()
        setupDisplayLink()
    }
    
    // MARK: - Private Methods
    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: WeakProxy(target: self), selector: #selector(update))
        displayLink?.add(to: .main, forMode: .common)
        updateSpeed()
    }
    
    private func invalidateDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    private func removeAllItems() {
        subviews.forEach { $0.removeFromSuperview() }
        visibleItems.removeAll()
    }
    
    private func clearCache() {
        reuseCache.removeAll()
        sizeCache.removeAll()
    }
    
    private func layoutInitialItems() {
        let viewLength = scrollDirection == .horizontal ? frame.width : frame.height
        
        // 1. 先布局主要可见区域
        var currentPosition: CGFloat = 0
        var layoutIndex = 0
        let targetLength = viewLength + offset
        
        while currentPosition < targetLength {
            let itemSize = addItem(at: currentPosition, withIndex: layoutIndex)
            layoutIndex = (layoutIndex + 1) % itemCount
            currentPosition += (scrollDirection == .horizontal ? itemSize.width : itemSize.height) + space
        }
        
        // 2. 在左侧添加items直到覆盖offset区域
        var leftPosition: CGFloat = 0
        var leftIndex = itemCount - 1
        
        while leftPosition > -offset {
            let itemSize = getItemSize(at: leftIndex)
            let itemLength = scrollDirection == .horizontal ? itemSize.width : itemSize.height
            leftPosition -= (itemLength + space)
            
            addItem(at: leftPosition, withIndex: leftIndex, isReverse: true)
            leftIndex = leftIndex > 0 ? leftIndex - 1 : itemCount - 1
        }
        
        // 3. 根据滚动方向设置currentIndex
        if scrollOrientation == .forward {
            currentIndex = layoutIndex - 1
        } else {
            currentIndex = leftIndex + 1
        }
    }
    
    private func updateSpeed() {
        speed = pixelsPerSecond / CGFloat(UIScreen.main.maximumFramesPerSecond)
    }
    
    @objc private func update() {
        visibleItems.forEach { (view) in
            let distance = scrollOrientation == .forward ? -speed : speed
            switch scrollDirection {
            case .horizontal:
                view.transform = view.transform.translatedBy(x: distance, y: 0)
            case .vertical:
                view.transform = view.transform.translatedBy(x: 0, y: distance)
            }
        }
        updateVisibleItems()
    }
    
    private func updateVisibleItems() {
        guard let first = visibleItems.first, let last = visibleItems.last else { return }
        
        let viewLength = scrollDirection == .horizontal ? frame.width : frame.height
        
        if scrollOrientation == .forward {
            // 移除已经移出视图的首个item
            if (scrollDirection == .horizontal ? first.frame.maxX : first.frame.maxY) < 0 {
                visibleItems.removeFirst()
                reuseItem(first)
            }
            
            // 在末尾添加新的item
            let lastEdge = scrollDirection == .horizontal ? last.frame.maxX : last.frame.maxY
            if lastEdge <= viewLength + offset {
                currentIndex = (currentIndex + 1) % itemCount
                let origin = lastEdge + space
                addItem(at: origin, withIndex: currentIndex)
            }
        } else {
            // 移除已经移出视图的最后一个item
            if (scrollDirection == .horizontal ? last.frame.minX : last.frame.minY) > viewLength {
                visibleItems.removeLast()
                reuseItem(last)
            }
            
            // 在头部添加新的item
            let firstEdge = scrollDirection == .horizontal ? first.frame.minX : first.frame.minY
            if firstEdge >= -offset {
                currentIndex = currentIndex > 0 ? currentIndex - 1 : itemCount - 1
                let itemSize = getItemSize(at: currentIndex)
                let origin = firstEdge - space - (scrollDirection == .horizontal ? itemSize.width : itemSize.height)
                addItem(at: origin, withIndex: currentIndex, isReverse: true)
            }
        }
    }
    
    @discardableResult
    private func addItem(at position: CGFloat, withIndex index: Int, isReverse: Bool = false) -> CGSize {
        let itemSize = getItemSize(at: index)
        guard let item = dataSourse?.marqueeView(self, itemForIndexAt: index) else { return .zero }
        
        let frame: CGRect
        switch scrollDirection {
        case .horizontal:
            frame = CGRect(x: position, y: 0, width: itemSize.width, height: itemSize.height)
        case .vertical:
            frame = CGRect(x: 0, y: position, width: itemSize.width, height: itemSize.height)
        }
        
        item.frame = frame
        addSubview(item)
        
        isReverse ? visibleItems.insert(item, at: 0) : visibleItems.append(item)
        return itemSize
    }
    
    private func getItemSize(at index: Int) -> CGSize {
        if let size = sizeCache[index] { return size }
        let size = dataSourse?.marqueeView(self, itemSizeForIndexAt: index) ?? .zero
        sizeCache[index] = size
        return size
    }
    
    private func reuseItem(_ item: OYMarqueeViewItem) {
        item.removeFromSuperview()
        if reuseCache[item.reuseIdentifier] == nil {
            reuseCache[item.reuseIdentifier] = LinkQueue<OYMarqueeViewItem>()
        }
        reuseCache[item.reuseIdentifier]?.enqueue(item)
    }
    
    // MARK: - Layout
    public override func layoutSubviews() {
        super.layoutSubviews()
        guard oldFrame != frame else { return }
        oldFrame = frame
        reloadData()
    }
}

// MARK: - WeakProxy
private final class WeakProxy: NSObject {
    weak var target: NSObjectProtocol?
    
    init(target: NSObjectProtocol) {
        self.target = target
        super.init()
    }
    
    override func responds(to selector: Selector!) -> Bool {
        return (target?.responds(to: selector) ?? false) || super.responds(to: selector)
    }
    
    override func forwardingTarget(for selector: Selector!) -> Any? {
        return target
    }
}
