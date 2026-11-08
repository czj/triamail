# Homebrew cask, served straight from this repository (no separate tap repository):
#   brew tap czj/triamail https://github.com/czj/triamail
#   brew install --cask triamail
# Always the latest release; the app then updates itself with Sparkle.
cask "triamail" do
  version :latest
  sha256 :no_check

  url "https://github.com/czj/triamail/releases/latest/download/Triamail.dmg"
  name "Triamail"
  desc "Mail client for triaging email and acting on it"
  homepage "https://github.com/czj/triamail"

  auto_updates true
  depends_on macos: ">= :tahoe"

  app "Triamail.app"

  # Releases without an Apple Developer ID are only signed ad hoc: without this, Gatekeeper refuses to open them.
  postflight do
    system_command "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "#{appdir}/Triamail.app"]
  end

  zap trash: [
    "~/Library/Caches/io.github.czj.triamail",
    "~/Library/HTTPStorages/io.github.czj.triamail",
    "~/Library/Preferences/io.github.czj.triamail.plist",
  ]
end
