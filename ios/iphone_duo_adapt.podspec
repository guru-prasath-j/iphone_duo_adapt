Pod::Spec.new do |s|
  s.name             = 'iphone_duo_adapt'
  s.version          = '0.2.0'
  s.summary          = 'iPhone Duo hinge and fold bridge for Flutter.'
  s.description      = <<-DESC
Reads UIHingeInteraction and UIView reserved regions (iOS 27.1) and sends them
to Flutter. Compiles to a no-op stub with older SDKs.
                       DESC
  s.homepage         = 'https://github.com/guru-prasath-j/iphone_duo_adapt'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Guruprasath J' => 'guruprasathjay@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'iphone_duo_adapt/Sources/iphone_duo_adapt/**/*.{h,m}'
  s.public_header_files = 'iphone_duo_adapt/Sources/iphone_duo_adapt/include/**/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
