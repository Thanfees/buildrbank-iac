"""
Fake keys, set before anything imports the app.

app/settings.py refuses to start without OPENROUTER_API_KEY, SUPABASE_URL
and SUPABASE_KEY. On your laptop they come from .env. On GitHub's machine
there is no .env, so we put obvious fakes here.

`setdefault` means a real value already in the environment wins. And because
load_dotenv() never overwrites what is already set, these fakes also win over
your real .env when you run pytest locally. The tests behave the same in both
places, which is the only way a test is worth anything.

Nothing in the test suite calls a model or a database, so fakes are enough.
"""
import os
import sys
from pathlib import Path

# Make `import app` work however pytest was started.
#
# `python -m pytest` puts the current folder on the import path; a bare
# `pytest` does not. Without this line the tests pass on your laptop and
# fail on GitHub with "No module named 'app'" - which is a miserable way
# to spend twenty minutes. scripts/check.py does the same thing, for the
# same reason.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

os.environ.setdefault("OPENROUTER_API_KEY", "test-key-not-real")
os.environ.setdefault("SUPABASE_URL", "https://example.supabase.co")
os.environ.setdefault("SUPABASE_KEY", "test-key-not-real")
