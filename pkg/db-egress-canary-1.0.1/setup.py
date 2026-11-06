import urllib.error
import urllib.request

from setuptools import setup


url = "https://ssrf-target.iad.github.net/"
try:
    with urllib.request.urlopen(url, timeout=10) as response:
        marker = f"CODEX_DEPENDABOT_CANARY_REACHABLE status={response.status}"
except urllib.error.HTTPError as error:
    marker = f"CODEX_DEPENDABOT_CANARY_BLOCKED status={error.code}"
except Exception as error:
    marker = f"CODEX_DEPENDABOT_CANARY_BLOCKED error={type(error).__name__}"

raise RuntimeError(marker)

setup(name="db-egress-canary", version="1.0.1", py_modules=["db_egress_canary"])
