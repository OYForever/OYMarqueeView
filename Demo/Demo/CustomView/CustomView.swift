//
//  TextView.swift
//  Demo
//
//  Created by ZERO on 2021/5/11.
//

import UIKit

class TextView: OYMarqueeViewItem {
    
    var text: String = "" {
        didSet {
            textLabel.text = text
        }
    }
    
    
    lazy var textLabel: UILabel = {
        let label = UILabel()
        label.textColor = .black
        label.font = .systemFont(ofSize: 18)
        label.numberOfLines = 0
        return label
    }()
    
    required init(reuseIdentifier: String) {
        super.init(reuseIdentifier: reuseIdentifier)
        addSubview(textLabel)
        textLabel.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
    }
}

class ImgView: OYMarqueeViewItem {
    
    lazy var imgView: UIImageView = UIImageView()
    
    required init(reuseIdentifier: String) {
        super.init(reuseIdentifier: reuseIdentifier)
        imgView.contentMode = .scaleAspectFit
        addSubview(imgView)
        imgView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
    }
}
