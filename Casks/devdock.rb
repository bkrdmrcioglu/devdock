cask "devdock" do
  version "0.3.0"
  sha256 "135872f10bd3dc43c8df58ca670add676eff1ff085b16cc3c93130dcec32d6b7"

  url "https://github.com/bkrdmrcioglu/devdock/releases/download/v0.3.0/DevDock-0.3.0.zip"
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
