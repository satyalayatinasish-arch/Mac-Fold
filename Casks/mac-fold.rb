cask "mac-fold" do
  version "1.0.7"
  sha256 "2936478e17347d6c9da919372a6de56b0a934a8a57034275df94b78cb92863a7"

  url "https://github.com/satyalayatinasish-arch/Mac-Fold/releases/download/v#{version}/Mac-Fold-#{version}.dmg"
  name "Mac Fold"
  desc "Lid-angle-driven 3D desktop fold effect for compatible MacBooks"
  homepage "https://github.com/satyalayatinasish-arch/Mac-Fold"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :sonoma

  app "Mac Fold.app"

  zap trash: [
    "~/Library/Application Support/local.yatin.mac-fold",
    "~/Library/Preferences/local.yatin.mac-fold.plist",
  ]
end
