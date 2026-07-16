Pod::Spec.new do |s|
  s.name = 'wts_sdk'
  s.version = '0.2.0-alpha.1'
  s.summary = 'Official wts.is Flutter SDK.'
  s.homepage = 'https://wts.is'
  s.license = { :type => 'Apache-2.0' }
  s.author = { 'Wetus' => 'info@wetus.co' }
  s.source = { :path => '.' }
  s.source_files = 'wts_sdk/Sources/wts_sdk/**/*.swift'
  s.platform = :ios, '15.0'
  s.dependency 'Flutter'
  s.dependency 'WtsSDK', '0.2.0-alpha.1'
  s.swift_version = '5.9'
end
