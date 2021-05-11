//
//  ViewController.swift
//  Demo
//
//  Created by ZERO on 2021/5/11.
//

import UIKit
import SnapKit
import OYMarqueeView

class ViewController: UIViewController {

    lazy var dataSource: [[String: String]] = {
        let dataSource = [
            ["type": "0", "content": "基于Swift5的轻量级跑马灯视图，支持横向或竖向滚动，仿cell复用机制支持视图复用，可使用约束布局，支持snapkit"],
            ["type": "0", "content": "https://github.com/OYForever/OYMarqueeView"],
            ["type": "1", "content": "image1"],
            ["type": "0", "content": "478027478@qq.com"],
            ["type": "1", "content": "image2"],
            ["type": "1", "content": "image1"],
            ["type": "0", "content": "感谢观看"],
            ["type": "0", "content": "😁😁😁😁😁"]
        ]
        return dataSource
    }()
    
    
    let marqueeViewH = OYMarqueeView(frame: CGRect(x: 0, y: 100, width: UIScreen.main.bounds.width, height: 50))
    let marqueeViewV = OYMarqueeView(scrollDirection: .vertical)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        view.addSubview(marqueeViewH)
        marqueeViewH.backgroundColor = .green
        marqueeViewH.dataSourse = self
        marqueeViewH.register(TextView.self, forItemReuseIdentifier: String(describing: TextView.self))
        marqueeViewH.register(ImgView.self, forItemReuseIdentifier: String(describing: ImgView.self))
        
        view.addSubview(marqueeViewV)
        marqueeViewV.backgroundColor = .green
        marqueeViewV.dataSourse = self
        marqueeViewV.register(TextView.self, forItemReuseIdentifier: String(describing: TextView.self))
        marqueeViewV.register(ImgView.self, forItemReuseIdentifier: String(describing: ImgView.self))
        marqueeViewV.snp.makeConstraints { (make) in
            make.left.right.equalToSuperview().inset(20)
            make.top.equalTo(marqueeViewH.snp.bottom).offset(100)
            make.height.equalTo(300)
        }
    }
}

extension ViewController: OYMarqueeViewDataSource {
    func numberOfItems(in marqueeView: OYMarqueeView) -> Int {
        return dataSource.count
    }
    
    func marqueeView(_ marqueeView: OYMarqueeView, itemForIndexAt index: Int) -> OYMarqueeViewItem {
        if dataSource[index]["type"] == "0" {
            let item = marqueeView.dequeueReusableItem(withIdentifier: String(describing: TextView.self)) as! TextView
            item.text = dataSource[index]["content"]!
            return item
        } else {
            let item = marqueeView.dequeueReusableItem(withIdentifier: String(describing: ImgView.self)) as! ImgView
            item.imgView.image = UIImage(named: dataSource[index]["content"]!)
            return item
        }
    }
    
    func marqueeView(_ marqueeView: OYMarqueeView, itemSizeForIndexAt index: Int) -> CGSize {
        if dataSource[index]["type"] == "0" {
            if marqueeView == marqueeViewH {
                var size = dataSource[index]["content"]!.boundingRect(with: CGSize(width: Double(MAXFLOAT), height: 50.0), font: .systemFont(ofSize: 18))
                size.height = 50
                return size
            } else {
                return dataSource[index]["content"]!.boundingRect(with: CGSize(width: UIScreen.main.bounds.width - 40, height: CGFloat(MAXFLOAT)), font: .systemFont(ofSize: 18), lines: 0)
            }
        } else {
            return CGSize(width: 50, height: 50)
        }
    }
}

extension String {
    /// 计算单行文字size
    func boundingRect(with constrainedSize: CGSize, font: UIFont, lineSpacing: CGFloat? = nil) -> CGSize {
        let attritube = NSMutableAttributedString(string: self)
        let range = NSRange(location: 0, length: attritube.length)
        attritube.addAttributes([NSAttributedString.Key.font: font], range: range)
        if lineSpacing != nil {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = lineSpacing!
            attritube.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraphStyle, range: range)
        }
        
        let rect = attritube.boundingRect(with: constrainedSize, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        var size = rect.size
        
        if let currentLineSpacing = lineSpacing {
            // 文本的高度减去字体高度小于等于行间距，判断为当前只有1行
            let spacing = size.height - font.lineHeight
            if spacing <= currentLineSpacing && spacing > 0 {
                size = CGSize(width: size.width, height: font.lineHeight)
            }
        }
        size.height = CGFloat(ceilf(Float(size.height)))
        size.width = CGFloat(ceilf(Float(size.width)))
        return size
    }
    
    /// 计算多行文字size
    func boundingRect(with constrainedSize: CGSize, font: UIFont, lineSpacing: CGFloat? = nil, lines: Int) -> CGSize {
        if lines < 0 {
            return .zero
        }
        
        let size = boundingRect(with: constrainedSize, font: font, lineSpacing: lineSpacing)
        if lines == 0 {
            return size
        }
        
        let currentLineSpacing = (lineSpacing == nil) ? (font.lineHeight - font.pointSize) : lineSpacing!
        let maximumHeight = font.lineHeight * CGFloat(lines) + currentLineSpacing * CGFloat(lines - 1)
        if size.height >= maximumHeight {
            return CGSize(width: size.width, height: maximumHeight)
        }
        
        return size
    }
}
