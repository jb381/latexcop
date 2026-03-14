# 👮 latexcop

[![Python 3.12+](https://img.shields.io/badge/python-3.12+-blue?logo=python&logoColor=white)](https://www.python.org)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Code style: Ruff](https://img.shields.io/badge/code%20style-ruff-purple?logo=ruff)](https://docs.astral.sh/ruff/)

*Stop guessing. Start tracking. Your LaTeX progress, (semi) automated.*

---

> **The problem:** Many academic courses require continuous weekly progress on your paper — *"Write at least 1000 characters per week!"* — but manually checking this is tedious and error-prone.
>
> **The fix:** Point **latexcop** at your Git repository. It walks your commit history, strips LaTeX comments, and tells you *exactly* how many real character changes you've made.

## 🔍 How It Works

```
  Git Commits  →  latexcop  →  Progress Table + CSV
  (your repo)     (compares)   (per period)
```

1. You write your LaTeX paper in a **Git repository** — [Overleaf has built-in Git support](https://docs.overleaf.com/integrations-and-add-ons/git-integration-and-github-synchronization/git-integration) — and commit regularly.
2. You point latexcop at that repo via a simple `.env` file.
3. It compares snapshots of your `.tex` file period by period and counts **real characters** changed — ignoring `% comments`.
4. You get a clean progress table and a CSV export.

## ✨ Features

- 🔄 **Automated Tracking** — fetches remote commits and computes character diffs per period
- ⌨️ **CLI Interface** — override environment variables via command-line arguments
- 🧹 **Comment Stripping** — LaTeX comments (`% …`) are ignored so you can't game the stats
- ⚠️ **Safety Warnings** — alerts you about uncommitted changes or a diverged branch
- 📊 **CSV Export** — saves weekly results to `progress.csv`
- ⚙️ **Fully Configurable** — any repo, any file, any interval (weekly / biweekly / monthly)

## 🚀 Quickstart

### Prerequisites

- **Python 3.12+**
- **Git**
- [**uv**](https://github.com/astral-sh/uv) — the blazing-fast Python package manager

### 1. Clone & configure

```bash
git clone https://github.com/jb381/latexcop.git
cd latexcop
cp .env.example .env
```

Edit `.env` — set REPO_DIR and START_DATE

### 2. Run

You can run it using the default configuration from your `.env` file:

```bash
uv run progress_tracker.py
```

Or override any setting via the command line:

```bash
uv run progress_tracker.py --start-date "2024-01-01 12:00:00" --min-chars 1500
```

### 3. Profit

```
🎯 Current Period 2 Progress: 1423/1000 chars (Goal met! 🎉)
--------------------------------------------------------------------------------
Period | Start Date       | End Date         | Diff   | Target Met | Locked
--------------------------------------------------------------------------------
1      | 2025-01-06 12:00 | 2025-01-13 12:00 | 1087   | Yes        | Yes
2      | 2025-01-13 12:00 | 2025-01-20 12:00 | 1423   | Yes        | No (Current)
--------------------------------------------------------------------------------
```

## ⚙️ Configuration

All settings live in `.env` **OR** can be passed as CLI arguments. Copy `.env.example` to get started:

| Variable | CLI Argument | Description | Default |
|---|---|---|---|
| `START_DATE` | `--start-date` | First period start date (`YYYY-MM-DD HH:MM:SS`) | — *(required)* |
| `REPO_DIR` | `--repo-dir` | Absolute path to your Git repository | — *(required)* |
| `FILE_PATH` | `--file-path` | LaTeX file path, relative to `REPO_DIR` | `main.tex` |
| `CSV_OUT` | `--csv-out` | Output CSV filename | `progress.csv` |
| `MIN_CHARS` | `--min-chars` | Minimum character diff required per period | `1000` |
| `INTERVAL_DAYS` | `--interval-days` | Period length in days (`7`=weekly, `14`=biweekly) | `7` |

## 📂 Project Structure

```
latexcop/
├── progress_tracker.py    # Main professional script
├── pyproject.toml         # Project metadata & Ruff config
├── .env.example           # Example configuration
├── LICENSE                # MIT License
└── README.md
```

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to open an issue or submit a pull request.

## 📄 License

[MIT](LICENSE) — use it, fork it, make it yours.
