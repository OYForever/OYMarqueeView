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

public protocol OYMarqueeViewDelegate: AnyObject {
    func marqueeView(_ marqueeView: OYMarqueeView, didDisplayItemAt index: Int)
    func marqueeView(_ marqueeView: OYMarqueeView, didSelectItemAt index: Int)
}

public extension OYMarqueeViewDelegate {
    func marqueeView(_ marqueeView: OYMarqueeView, didDisplayItemAt index: Int) {}
    func marqueeView(_ marqueeView: OYMarqueeView, didSelectItemAt index: Int) {}
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
    @available(*, deprecated, renamed: "dataSource")
    public weak var dataSourse: OYMarqueeViewDataSource? {
        get { dataSource }
        set { dataSource = newValue }
    }

    public weak var dataSource: OYMarqueeViewDataSource?
    public weak var delegate: OYMarqueeViewDelegate?

    private(set) var scrollDirection: ScrollDirection
    public var scrollOrientation: ScrollOrientation = .forward

    /// 每秒移动的像素点
    public var pixelsPerSecond: CGFloat = 50

    /// 是否在 App 进入后台时自动暂停，回到前台自动恢复
    public var autoPauseWhenAppInactive: Bool = true

    /// 当前是否暂停滚动
    public private(set) var isPaused: Bool = false {
        didSet {
            displayLink?.isPaused = isPaused
            if !isPaused {
                lastTimestamp = nil
            }
        }
    }

    @available(*, deprecated, renamed: "itemSpacing")
    public var space: CGFloat {
        get { itemSpacing }
        set { itemSpacing = max(0, newValue) }
    }

    public var itemSpacing: CGFloat = 30 {
        didSet {
            itemSpacing = max(0, itemSpacing)
        }
    }

    @available(*, deprecated, renamed: "preloadOffset")
    public var offset: CGFloat {
        get { preloadOffset }
        set { preloadOffset = max(0, newValue) }
    }

    public var preloadOffset: CGFloat = 100 {
        didSet {
            preloadOffset = max(0, preloadOffset)
        }
    }

    private var currentIndex = 0
    private var itemCount = 0
    private var oldBounds: CGRect?

    private var visibleItems: [OYMarqueeViewItem] = []
    private var visibleItemIndices: [ObjectIdentifier: Int] = [:]
    private var reuseCache: [String: LinkQueue<OYMarqueeViewItem>] = [:]
    private var classCache: [String: AnyClass] = [:]
    private var sizeCache: [Int: CGSize] = [:]

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?

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
        setupDisplayLinkIfNeeded()
        observeApplicationState()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        invalidateDisplayLink()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            invalidateDisplayLink()
        } else if !visibleItems.isEmpty {
            setupDisplayLinkIfNeeded()
        }
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

        guard let dataSource else { return }
        let count = dataSource.numberOfItems(in: self)
        guard count > 0 else { return }

        itemCount = count
        currentIndex = 0

        layoutInitialItems()
        setupDisplayLinkIfNeeded()
        isPaused = false
    }

    /// 暂停滚动
    public func pause() {
        isPaused = true
    }

    /// 恢复滚动
    public func resume() {
        guard !visibleItems.isEmpty else { return }
        setupDisplayLinkIfNeeded()
        isPaused = false
    }

    /// 停止滚动并清空内容
    public func stop() {
        invalidateDisplayLink()
        removeAllItems()
        clearCache()
        itemCount = 0
        currentIndex = 0
        isPaused = false
    }


    // MARK: - Private Methods
    private func observeApplicationState() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func handleApplicationDidEnterBackground() {
        guard autoPauseWhenAppInactive else { return }
        pause()
    }

    @objc private func handleApplicationWillEnterForeground() {
        guard autoPauseWhenAppInactive else { return }
        resume()
    }

    private func setupDisplayLinkIfNeeded() {
        guard displayLink == nil else { return }

        let link = CADisplayLink(target: WeakProxy(target: self), selector: #selector(update(_:)))
        if #available(iOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 60)
        } else {
            link.preferredFramesPerSecond = 60
        }
        link.add(to: .main, forMode: .common)
        link.isPaused = isPaused
        displayLink = link
    }

    private func invalidateDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = nil
    }

    private func removeAllItems() {
        subviews.forEach { $0.removeFromSuperview() }
        visibleItems.removeAll()
        visibleItemIndices.removeAll()
    }

    private func clearCache() {
        reuseCache.removeAll()
        sizeCache.removeAll()
    }

    private func layoutInitialItems() {
        let viewLength = axisLength(of: bounds)

        var currentPosition: CGFloat = 0
        var layoutIndex = 0
        let targetLength = viewLength + preloadOffset

        while currentPosition < targetLength {
            let itemSize = addItem(at: currentPosition, withIndex: layoutIndex)
            layoutIndex = (layoutIndex + 1) % itemCount
            currentPosition += axisLength(of: itemSize) + itemSpacing
        }

        var leftPosition: CGFloat = 0
        var leftIndex = itemCount - 1

        while leftPosition > -preloadOffset {
            let itemSize = getItemSize(at: leftIndex)
            leftPosition -= axisLength(of: itemSize) + itemSpacing

            addItem(at: leftPosition, withIndex: leftIndex, isReverse: true)
            leftIndex = leftIndex > 0 ? leftIndex - 1 : itemCount - 1
        }

        currentIndex = scrollOrientation == .forward ? max(layoutIndex - 1, 0) : min(leftIndex + 1, itemCount - 1)
    }

    @objc private func update(_ displayLink: CADisplayLink) {
        guard !visibleItems.isEmpty else { return }

        let deltaTime: CGFloat
        if let lastTimestamp {
            deltaTime = CGFloat(displayLink.timestamp - lastTimestamp)
        } else {
            deltaTime = CGFloat(displayLink.targetTimestamp - displayLink.timestamp)
        }
        self.lastTimestamp = displayLink.timestamp

        let step = max(0, pixelsPerSecond) * max(0, deltaTime)
        let distance = scrollOrientation == .forward ? -step : step

        visibleItems.forEach { view in
            switch scrollDirection {
            case .horizontal:
                view.frame.origin.x += distance
            case .vertical:
                view.frame.origin.y += distance
            }
        }

        updateVisibleItems()
    }

    private func updateVisibleItems() {
        guard let first = visibleItems.first, let last = visibleItems.last else { return }

        let viewLength = axisLength(of: bounds)

        if scrollOrientation == .forward {
            if axisMax(of: first.frame) < 0 {
                visibleItems.removeFirst()
                reuseItem(first)
            }

            let lastEdge = axisMax(of: last.frame)
            if lastEdge <= viewLength + preloadOffset {
                currentIndex = (currentIndex + 1) % itemCount
                let origin = lastEdge + itemSpacing
                addItem(at: origin, withIndex: currentIndex)
            }
        } else {
            if axisMin(of: last.frame) > viewLength {
                visibleItems.removeLast()
                reuseItem(last)
            }

            let firstEdge = axisMin(of: first.frame)
            if firstEdge >= -preloadOffset {
                currentIndex = currentIndex > 0 ? currentIndex - 1 : itemCount - 1
                let itemSize = getItemSize(at: currentIndex)
                let origin = firstEdge - itemSpacing - axisLength(of: itemSize)
                addItem(at: origin, withIndex: currentIndex, isReverse: true)
            }
        }
    }

    @discardableResult
    private func addItem(at position: CGFloat, withIndex index: Int, isReverse: Bool = false) -> CGSize {
        let itemSize = getItemSize(at: index)
        guard let item = dataSource?.marqueeView(self, itemForIndexAt: index) else { return .zero }

        item.transform = .identity

        switch scrollDirection {
        case .horizontal:
            item.frame = CGRect(x: position, y: 0, width: itemSize.width, height: itemSize.height)
        case .vertical:
            item.frame = CGRect(x: 0, y: position, width: itemSize.width, height: itemSize.height)
        }

        addSubview(item)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleItemTap(_:)))
        item.addGestureRecognizer(tap)
        item.isUserInteractionEnabled = true
        isReverse ? visibleItems.insert(item, at: 0) : visibleItems.append(item)
        visibleItemIndices[ObjectIdentifier(item)] = index
        delegate?.marqueeView(self, didDisplayItemAt: index)
        return itemSize
    }

    private func getItemSize(at index: Int) -> CGSize {
        if let size = sizeCache[index] { return size }
        let size = dataSource?.marqueeView(self, itemSizeForIndexAt: index) ?? .zero
        sizeCache[index] = size
        return size
    }

    private func reuseItem(_ item: OYMarqueeViewItem) {
        item.removeFromSuperview()
        visibleItemIndices.removeValue(forKey: ObjectIdentifier(item))
        if reuseCache[item.reuseIdentifier] == nil {
            reuseCache[item.reuseIdentifier] = LinkQueue<OYMarqueeViewItem>()
        }
        reuseCache[item.reuseIdentifier]?.enqueue(item)
    }

    @objc private func handleItemTap(_ gesture: UITapGestureRecognizer) {
        guard let item = gesture.view as? OYMarqueeViewItem else { return }
        guard let index = visibleItemIndices[ObjectIdentifier(item)] else { return }
        delegate?.marqueeView(self, didSelectItemAt: index)
    }

    private func axisLength(of size: CGSize) -> CGFloat {
        scrollDirection == .horizontal ? size.width : size.height
    }

    private func axisLength(of rect: CGRect) -> CGFloat {
        scrollDirection == .horizontal ? rect.width : rect.height
    }

    private func axisMin(of rect: CGRect) -> CGFloat {
        scrollDirection == .horizontal ? rect.minX : rect.minY
    }

    private func axisMax(of rect: CGRect) -> CGFloat {
        scrollDirection == .horizontal ? rect.maxX : rect.maxY
    }

    // MARK: - Layout
    public override func layoutSubviews() {
        super.layoutSubviews()
        guard oldBounds != bounds else { return }
        oldBounds = bounds
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
        (target?.responds(to: selector) ?? false) || super.responds(to: selector)
    }

    override func forwardingTarget(for selector: Selector!) -> Any? {
        target
    }
}
