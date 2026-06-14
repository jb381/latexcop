import sys
from pathlib import Path

# Add the project root so tests can import progress_tracker.py
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
