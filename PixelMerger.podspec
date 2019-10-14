Pod::Spec.new do |spec|

  spec.name         = "PixelMerger"
  spec.version      = "1.0.0"

  spec.summary      = "..."
  spec.description  = <<-DESC
  					          ...
                      DESC

  spec.homepage     = "http://hexagons.se"

  # spec.license      = { :type => "MIT", :file => "LICENSE" }

  spec.author             = { "Hexagons" => "anton@hexagons.se" }
  spec.social_media_url   = "https://twitter.com/anton_hexagons"

  spec.ios.deployment_target = "11.0"
  spec.osx.deployment_target = "10.13"
  # spec.tvos.deployment_target = "11.0"

  spec.swift_version = '5.0'

  spec.source       = { :git => "https://github.com/hexagons/...git", :branch => "master", :tag => "#{spec.version}" }

  spec.source_files  = "Sources", "Sources/**/*.swift"

  # spec.ios.exclude_files = "" 
  # spec.osx.exclude_files = ""
  # spec.tvos.exclude_files = ""

  # spec.ios.resources = ""
  # spec.osx.resources = ""
  # spec.tvos.resources = ""

  spec.dependency 'LiveValues'
  spec.dependency 'RenderKit'
  spec.dependency 'PixelKit'

end
