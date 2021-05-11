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
        super.init(frame: CGRect.zero)
    }
    
    required public init(reuseIdentifier: String) {
        self.reuseIdentifier = reuseIdentifier
        super.init(frame: CGRect.zero)
    }
    
    @available(*, unavailable)
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - MarqueeViewDataSource
public protocol OYMarqueeViewDataSource: AnyObject {
    ///一共有多少个item
    func numberOfItems(in marqueeView: OYMarqueeView) -> Int
    ///当前item视图
    func marqueeView(_ marqueeView: OYMarqueeView, itemForIndexAt index: Int) -> OYMarqueeViewItem
    ///当前item的大小
    func marqueeView(_ marqueeView: OYMarqueeView, itemSizeForIndexAt index: Int) -> CGSize
}

public final class OYMarqueeView: UIView {
    /// 弱代理
    class WeakProxy: NSObject {
        weak var target: NSObjectProtocol?
        
        init(target: NSObjectProtocol) {
            self.target = target
            super.init()
        }
        
        override func responds(to aSelector: Selector!) -> Bool {
            return (target?.responds(to: aSelector) ?? false) || super.responds(to: aSelector)
        }
        
        override func forwardingTarget(for aSelector: Selector!) -> Any? {
            return target
        }
    }
    /// 滚动方向
    public enum ScrollDirection {
        case horizontal
        case vertical
    }
    /// 滚动方向，默认横向
    private(set) var scrollDirection: ScrollDirection = .horizontal
    /// 移动速度最小为0，每次屏幕刷新所移动的距离（单位dp），该值取绝对值
    public var speed: CGFloat = 1
    /// 数据源
    public weak var dataSourse: OYMarqueeViewDataSource?
    ///item间距 默认30
    public var space: CGFloat  = 30
    /// 展示项目最少超出视图间距
    private var offset: CGFloat = 100
    /// 当前最后一个角标
    private var currentIndex = 0
    /// 上一次的frame
    private var oldFrame: CGRect?
    /// 可视view数组
    private var visibleViewArr: [OYMarqueeViewItem] = [OYMarqueeViewItem]()
    /// 重用view缓存
    private var reuseViewCache: [String: LinkQueue<OYMarqueeViewItem>] = [String: LinkQueue<OYMarqueeViewItem>]()
    /// 重用id和class对应关系缓存
    private var idCache: [String: AnyClass] = [String: AnyClass]()
    /// 定时器
    private var timer: CADisplayLink?
    /// 条目个数
    private var itemCount: Int = 0
    /// 大小缓存
    private var sizeCache: [Int: CGSize] = [Int: CGSize]()
    
    // MARK: - Init
    deinit {
        timer?.invalidate()
        timer = nil
    }
    
    public init(frame: CGRect = .zero, scrollDirection: ScrollDirection = .horizontal) {
        super.init(frame: frame)
        self.scrollDirection = scrollDirection
        self.clipsToBounds = true
        self.initTimer()
    }
    
    public init() {
        super.init(frame: CGRect.zero)
        self.clipsToBounds = true
        self.initTimer()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func initTimer() {
        timer = CADisplayLink(target: WeakProxy(target: self), selector: #selector(run))
        timer?.add(to: .main, forMode: .common)
    }
    
    // MARK: - Public Func
    public func register(_ itemClass: AnyClass, forItemReuseIdentifier identifier: String) {
        idCache[identifier] = itemClass
    }
    
    public func dequeueReusableItem(withIdentifier identifier: String) -> OYMarqueeViewItem {
        return viewFromCache(identifier)
    }
    
    public func reloadData() {
        timer?.invalidate()
        timer = nil
        subviews.forEach { (view) in
            view.removeFromSuperview()
        }
        clearCache()
        
        guard let dataSourse = dataSourse, dataSourse.numberOfItems(in: self) > 0 else { return }
        
        currentIndex = 0
        switch scrollDirection {
        case .horizontal:
            let frameWidth = frame.width
            var currentWidth: CGFloat = 0
            while currentWidth < frameWidth + offset {
                itemCount = dataSourse.numberOfItems(in: self)
                let itemSize = addItem(origin: currentWidth)
                currentIndex += 1
                if currentIndex == itemCount {
                    currentIndex = 0
                }
                currentWidth += itemSize.width + space
            }
        case .vertical:
            let frameHeight = frame.height
            var currentHeight: CGFloat = 0
            while currentHeight < frameHeight + offset {
                itemCount = dataSourse.numberOfItems(in: self)
                let itemSize = addItem(origin: currentHeight)
                currentIndex += 1
                if currentIndex == itemCount {
                    currentIndex = 0
                }
                currentHeight += itemSize.height + space
            }
        }
        
        initTimer()
    }
    
    
    // MARK: - Update View
    public override func layoutSubviews() {
        super.layoutSubviews()
        // 布局更新
        let frame = self.frame
        if oldFrame == frame {
            return
        }
        oldFrame = frame
        reloadData()
    }
    
    private func updateView() {
        let frameWidth = frame.width
        let frameHeight = frame.height
        guard let firstShowView = visibleViewArr.first,
              let lastShowView = visibleViewArr.last else {
            return
        }
        switch scrollDirection {
        case .horizontal:
            if firstShowView.frame.maxX < 0 {
                visibleViewArr.removeFirst()
                saveViewToCache(firstShowView)
            }
            let lastViewRight = lastShowView.frame.maxX
            if lastViewRight <= frameWidth + offset {
                if currentIndex < itemCount - 1{
                    currentIndex += 1
                } else {
                    currentIndex = 0
                }
                addItem(origin: lastViewRight + space)
            }
        case .vertical:
            if firstShowView.frame.maxY < 0 {
                visibleViewArr.removeFirst()
                saveViewToCache(firstShowView)
            }
            let lastViewBottom = lastShowView.frame.maxY
            if lastViewBottom <= frameHeight + offset {
                if currentIndex < itemCount - 1{
                    currentIndex += 1
                } else {
                    currentIndex = 0
                }
                addItem(origin: lastViewBottom + space)
            }
        }
    }
    
    // MARK: - Target
    @objc private func run() {
        visibleViewArr.forEach { (view) in
            switch scrollDirection {
            case .horizontal:
                view.transform = view.transform.translatedBy(x: -abs(speed), y: 0)
            case .vertical:
                view.transform = view.transform.translatedBy(x: 0, y: -abs(speed))
            }
        }
        updateView()
    }
    
    @discardableResult
    private func addItem(origin: CGFloat) -> CGSize {
        var itemSize = self.sizeCache[currentIndex]
        
        guard let dataSourse = dataSourse else {
            return CGSize.zero
        }
        
        if itemSize == nil || itemSize == CGSize.zero {
            itemSize = dataSourse.marqueeView(self, itemSizeForIndexAt: currentIndex)
            sizeCache[currentIndex] = itemSize
        }
        
        let item = dataSourse.marqueeView(self, itemForIndexAt: currentIndex)
        switch scrollDirection {
        case .horizontal:
            item.frame = CGRect(x: origin, y: 0, width: itemSize?.width ?? 0, height: itemSize?.height ?? 0)
        case .vertical:
            item.frame = CGRect(x: 0, y: origin, width: itemSize?.width ?? 0, height: itemSize?.height ?? 0)
        }
        addSubview(item)
        visibleViewArr.append(item)
        return itemSize ?? CGSize.zero
    }
    
    // MARK: - Cache
    private func saveViewToCache(_ view: OYMarqueeViewItem) {
        guard let viewQuene = reuseViewCache[view.reuseIdentifier] else {
            let linkQueue = LinkQueue<OYMarqueeViewItem>()
            linkQueue.enqueue(view)
            reuseViewCache[view.reuseIdentifier] = linkQueue
            return
        }
        viewQuene.enqueue(view)
    }
    
    private func viewFromCache(_ identifier: String) -> OYMarqueeViewItem {
        if let view = reuseViewCache[identifier]?.dequeue() {
            return view
        }
        guard let itemClass = idCache[identifier] as? OYMarqueeViewItem.Type else {
            fatalError("MarqueeView: unable to dequeue a item with identifier \(identifier) - must register a class for the identifier")
        }
        let item = itemClass.init(reuseIdentifier: identifier)
        return item
    }
    
    private func clearCache() {
        visibleViewArr.removeAll()
        reuseViewCache.removeAll()
        sizeCache.removeAll()
    }
}
