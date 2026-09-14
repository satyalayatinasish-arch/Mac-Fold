cask "mac-fold" do
  version "1.0.8"
  sha256 "3883f99d2934aad7f4a133b9b9f175455d08ebb368b07f1d8f9d25881277a58a"

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
