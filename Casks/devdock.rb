cask "devdock" do
  version "1.0.0"
  sha256 "PLACEHOLDER"

  url "https://github.com/bkrdmrcioglu/devdock/releases/download/v1.0.0/DevDock-1.0.0.zip"
  name "DevDock"
  desc "macOS developer workspace manager — scan, start/stop, and organize local dev stacks"
  homepage "https://github.com/bkrdmrcioglu/devdock"

  depends_on macos: :sonoma

  app "DevDock.app"

  zap trash: [
    "~/Library/Preferences/com.devdock.app.plist",
    "~/Library/Application Support/DevDock",
  ]
end
