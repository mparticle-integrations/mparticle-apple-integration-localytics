Pod::Spec.new do |s|
    s.name             = "mParticle-Localytics"
    s.version          = "6.0.0"
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
    s.ios.dependency 'Localytics', '3.7.0'
end
