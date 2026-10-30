"""
Does the thing we are about to ship still look right?

These four tests are not clever. Each one exists because something actually
went wrong once, and a test is the cheapest way to stop it going wrong twice.
That is the whole idea behind a test suite: it is a list of mistakes the
project has already made and does not intend to repeat.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def test_dockerfile_pins_the_python_version():
    """FROM python:3.12-slim, never python:latest.

    'latest' means 'whatever came out this morning'. On a brand new Python
    some of these libraries have no ready-made package yet, pip tries to
    build them from source, and your build turns into a four-minute hang
    that ends in an error nobody can read.
    """
    dockerfile = (ROOT / "Dockerfile").read_text()
    assert "python:latest" not in dockerfile
    assert "FROM python:3.12" in dockerfile


def test_requirements_cap_the_anthropic_version():
    """anthropic must have an upper limit.

    The original file said `anthropic>=0.109` with nothing on the right.
    pip happily installed 1.x, where `temperature` was removed from
    messages.create() - and the agent passes temperature=0 in six places.
    Every single message failed. An unbounded version is a time bomb with
    someone else's finger on the timer.
    """
    reqs = (ROOT / "requirements.txt").read_text()
    assert "anthropic>=0.109,<1.0" in reqs


def test_env_is_ignored():
    """.env must never be committed. It is the one file with real keys in it."""
    ignored = (ROOT / ".gitignore").read_text().splitlines()
    assert ".env" in [line.strip() for line in ignored]


def test_the_handbook_shipped():
    """scripts/data/bank_handbook.txt has to be in the repo.

    It nearly was not. .gitignore said `data/`, which matches ANY folder
    called data - including scripts/data/. The handbook was silently left
    out of the repo, and the seed script would have loaded zero knowledge
    chunks without printing a single error.

    Fixing it took one character: /data/ instead of data/. Finding it took
    a clean clone on a second machine. This test is cheaper than that.
    """
    handbook = ROOT / "scripts" / "data" / "bank_handbook.txt"
    assert handbook.exists(), "the handbook is missing from the repo"
    assert len(handbook.read_text()) > 1000, "the handbook looks truncated"
