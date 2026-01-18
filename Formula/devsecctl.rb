


class Devsecctl < Formula
  desc "macOS & Linux dev + security control center CLI (ports, docker helpers, snapshots, redaction)"
  homepage "https://github.com/zack40x/devsecctl"
  license "MIT"

  url "https://github.com/zack40x/devsecctl/archive/refs/tags/v0.1.1.tar.gz"
  sha256 "05a723f901da5928fa7395cf610b4e2e0196ce09013afc58f2a62e943895608d"

  head "https://github.com/zack40x/devsecctl.git", branch: "main"

  def install
    libexec.install Dir["modules"]
    libexec.install "devsecctl"
    bin.write_exec_script libexec/"devsecctl"
  end

  test do
    system "#{bin}/devsecctl", "--version"
    system "#{bin}/devsecctl", "help"
  end
end