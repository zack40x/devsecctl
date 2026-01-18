class Devsecctl < Formula
  desc "macOS & Linux dev + security control center CLI (ports, docker helpers, snapshots, redaction)"
  homepage "https://github.com/REPLACE_ME/devsecctl"
  license "MIT"

  # After you push + create a release tarball, replace the url+sha256 below.
  # url "https://github.com/REPLACE_ME/devsecctl/archive/refs/tags/v0.1.0.tar.gz"
  # sha256 "REPLACE_WITH_SHA256"

  head "https://github.com/REPLACE_ME/devsecctl.git", branch: "main"

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
