cask "devdock" do
  version "1.0.1"
  sha256 "3f04bc3556761349bc6e9bb0b464796ed580549c06be8a3e1231894438fde79d"

  url "https://github.com/bkrdmrcioglu/devdock/releases/download/v1.0.1/DevDock-1.0.1.zip"
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
