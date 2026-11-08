# Homebrew cask, served straight from this repository (no separate tap repository):
#   brew tap czj/triamail https://github.com/czj/triamail
#   brew install --cask triamail
# Always the latest release; the app then updates itself with Sparkle.
cask "triamail" do
  version :latest
  sha256 :no_check

  url "https://github.com/czj/triamail/releases/latest/download/Triamail.dmg"
  name "Triamail"
  desc "Mail client to triage emails and act on them"
  homepage "https://github.com/czj/triamail"

  auto_updates true
  depends_on macos: :tahoe

  app "Triamail.app"

  # Releases without an Apple Developer ID are only signed ad hoc: without this, Gatekeeper refuses to open them.
  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/Triamail.app"],
                          writable_paths: ["Triamail.app"], writable_base: :appdir
  end

  zap trash: [
    "~/Library/Caches/io.github.czj.triamail",
    "~/Library/HTTPStorages/io.github.czj.triamail",
    "~/Library/Preferences/io.github.czj.triamail.plist",
  ]
end
