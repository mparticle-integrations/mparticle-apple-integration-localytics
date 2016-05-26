Pod::Spec.new do |s|
    s.name             = "mParticle-Localytics"
    s.version          = "6.0.7"
    s.summary          = "Localytics integration for mParticle"

    s.description      = <<-DESC
                       This is the Localytics integration for mParticle.
                       DESC

    s.homepage         = "https://www.mparticle.com"
    s.license          = { :type => 'Apache 2.0', :file => 'LICENSE' }
    s.author           = { "mParticle" => "support@mparticle.com" }
    s.source           = { :git => "https://github.com/mparticle-integrations/mparticle-apple-integration-localytics.git", :tag => s.version.to_s }
    s.social_media_url = "https://twitter.com/mparticles"

    s.ios.deployment_target = "7.0"
    s.ios.source_files      = 'mParticle-Localytics/*.{h,m,mm}'
    s.ios.dependency 'mParticle-Apple-SDK/mParticle', '~> 6.0'
    s.ios.dependency 'Localytics', '3.8.0'
    s.frameworks = 'SystemConfiguration', 'CoreLocation', 'AdSupport'
    s.library = 'z', 'sqlite3'

    s.ios.pod_target_xcconfig = {
        'LIBRARY_SEARCH_PATHS' => '$(inherited) $(PODS_ROOT)/Localytics/**',
        'OTHER_LDFLAGS' => '$(inherited) -l"Localytics"'
    }
    s.ios.user_target_xcconfig = { 'OTHER_LDFLAGS' => '$(inherited) -l"Localytics" -framework "CoreLocation"' }
end
