Pod::Spec.new do |s|
  s.name                  = "OYMarqueeView"
  s.version               = "1.0.0"
  s.summary               = "基于Swift 5的轻量级跑马灯视图，支持横向或竖向滚动，仿cell复用机制支持视图复用"
  s.homepage              = "https://github.com/OYForever/OYMarqueeView"
  s.license               = "MIT"
  s.authors               = { "Zero" => "478027478@qq.com" }
  s.social_media_url      = "https://github.com/OYForever"
  s.ios.deployment_target = "8.0"
  s.source                = { :git => "https://github.com/OYForever/OYMarqueeView.git", :tag => s.version.to_s }
  s.source_files          = 'OYMarqueeView/**/*'
end