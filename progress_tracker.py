import csv
import datetime
import difflib
import logging
import os
import re
import subprocess
import sys
from argparse import ArgumentParser, Namespace
from dataclasses import asdict, dataclass

from dotenv import load_dotenv

# Set up logging
logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger(__name__)


@dataclass
class Config:
    """
    Configuration for the progress tracker.
    """

    start_date: datetime.datetime
    repo_dir: str
    file_path: str = "main.tex"
    csv_out: str = "progress.csv"
    min_chars: int = 1000
    interval_days: int = 7

    @classmethod
    def from_env_and_args(cls, args: Namespace) -> "Config":
        """
        Loads configuration from environment variables and command line arguments.
        """
        load_dotenv()

        start_str = args.start_date or os.getenv("START_DATE")
        if not start_str:
            logger.error("START_DATE is not set. Please configure it in .env or use --start-date.")
            sys.exit(1)

        try:
            start_date = datetime.datetime.strptime(start_str, "%Y-%m-%d %H:%M:%S")
        except ValueError:
            logger.error(
                "Invalid START_DATE format: '%s'. Expected 'YYYY-MM-DD HH:MM:SS'", start_str
            )
            sys.exit(1)

        repo_dir = args.repo_dir or os.getenv("REPO_DIR")
        if not repo_dir or not os.path.exists(repo_dir):
            logger.error("REPO_DIR '%s' not found or not set.", repo_dir)
            sys.exit(1)

        return cls(
            start_date=start_date,
            repo_dir=repo_dir,
            file_path=args.file_path or os.getenv("FILE_PATH", "main.tex"),
            csv_out=args.csv_out or os.getenv("CSV_OUT", "progress.csv"),
            min_chars=int(args.min_chars or os.getenv("MIN_CHARS", "1000")),
            interval_days=int(args.interval_days or os.getenv("INTERVAL_DAYS", "7")),
        )


@dataclass
class ProgressRecord:
    """
    Represents a single tracking period's progress.
    """

    Period: int
    Start: str
    End: str
    DiffChars: int
    TargetMet: str
    Locked: str


def run_git_command(args: list[str], cwd: str) -> str | None:
    """
    Runs a git command and returns its output. Returns None on failure.
    """
    try:
        return (
            subprocess.check_output(
                ["git", *args],
                cwd=cwd,
                stderr=subprocess.STDOUT,
            )
            .decode("utf-8")
            .strip()
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None


def get_commit_before(timestamp: datetime.datetime, config: Config) -> str | None:
    """
    Returns the commit hash right before the given timestamp on HEAD.
    """
    ts_str = timestamp.strftime("%Y-%m-%d %H:%M:%S")
    # Check if HEAD exists
    if run_git_command(["rev-parse", "HEAD"], config.repo_dir) is None:
        return None

    return run_git_command(["rev-list", "-n", "1", f"--before={ts_str}", "HEAD"], config.repo_dir)


def get_file_content_at_commit(commit: str, filepath: str, config: Config) -> str:
    """
    Returns the file content at a specific commit.
    """
    if not commit:
        return ""
    content = run_git_command(["show", f"{commit}:{filepath}"], config.repo_dir)
    return content if content is not None else ""


def get_current_file_content(filepath: str, config: Config) -> str:
    """
    Returns the current working tree content.
    """
    try:
        full_path = os.path.join(config.repo_dir, filepath)
        with open(full_path, encoding="utf-8") as f:
            return f.read()
    except Exception as e:
        logger.debug("Failed to read current file content: %s", e)
        return ""


def strip_latex_comments(text: str) -> str:
    """
    Removes comments from LaTeX source (from '%' to the end of the line).
    Also handles escaped percent signs (\\%) correctly.
    Lines that become purely whitespace after stripping are removed entirely
    to avoid counting 'comment-only' lines as newlines.
    """
    # Remove everything from % to end of line
    text = re.sub(r"(?<!\\)%.*", "", text)
    # Filter out lines that are now just whitespace
    lines = text.splitlines()
    clean_lines = [line for line in lines if line.strip()]
    return "\n".join(clean_lines)


def char_diff(text1: str, text2: str) -> int:
    """
    Computes absolute character additions and deletions between two strings,
    ignoring LaTeX comments.
    """
    text1_clean = strip_latex_comments(text1)
    text2_clean = strip_latex_comments(text2)

    matcher = difflib.SequenceMatcher(None, text1_clean, text2_clean)
    diff = 0
    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag == "replace":
            diff += (i2 - i1) + (j2 - j1)
        elif tag == "delete":
            diff += i2 - i1
        elif tag == "insert":
            diff += j2 - j1
    return diff


def auto_pull(config: Config) -> None:
    """
    Attempts to fetch and fast-forward pull from the remote repository.
    """
    remotes = run_git_command(["remote"], config.repo_dir)
    if not remotes:
        return

    logger.info("Fetching latest changes from remote...")
    if run_git_command(["fetch"], config.repo_dir) is None:
        logger.warning("Could not fetch from remote.")
        return

    logger.info("Attempting to pull (fast-forward only)...")
    if run_git_command(["merge", "--ff-only"], config.repo_dir) is None:
        logger.warning("Could not auto-pull from remote (branch diverged or uncommitted changes).")
    else:
        logger.info("Successfully pulled latest changes.")


def check_uncommitted_changes(config: Config) -> None:
    """
    Checks if there are uncommitted changes to FILE_PATH and warns the user.
    """
    status = run_git_command(["status", "--porcelain", config.file_path], config.repo_dir)
    if status:
        logger.warning("You have uncommitted changes in '%s'!", config.file_path)
        logger.warning(
            "These changes are included in the 'Current' diff, but they will NOT be locked "
            "in history until you commit them. Don't forget to commit and push!"
        )


def calculate_progress(config: Config) -> list[ProgressRecord]:
    """
    Calculates progress records based on git history and current state.
    """
    now = datetime.datetime.now()
    records = []

    period_start = config.start_date
    period_num = 1

    while period_start <= now:
        period_end = period_start + datetime.timedelta(days=config.interval_days)

        start_commit = get_commit_before(period_start, config)
        start_content = (
            get_file_content_at_commit(start_commit, config.file_path, config)
            if start_commit
            else ""
        )

        if now < period_end:
            # Current (incomplete) period
            end_content = get_current_file_content(config.file_path, config)
            locked = False
        else:
            # Locked (historical) period
            end_commit = get_commit_before(period_end, config)
            end_content = (
                get_file_content_at_commit(end_commit, config.file_path, config)
                if end_commit
                else ""
            )
            locked = True

        diff_count = char_diff(start_content, end_content)

        records.append(
            ProgressRecord(
                Period=period_num,
                Start=period_start.strftime("%Y-%m-%d %H:%M"),
                End=period_end.strftime("%Y-%m-%d %H:%M"),
                DiffChars=diff_count,
                TargetMet="Yes" if diff_count >= config.min_chars else "No",
                Locked="Yes" if locked else "No (Current)",
            )
        )

        period_start = period_end
        period_num += 1

    return records


def parse_args() -> Namespace:
    """
    Parses command line arguments.
    """
    parser = ArgumentParser(description="Track progress of a LaTeX paper via Git history.")
    parser.add_argument("--start-date", help="Start date (YYYY-MM-DD HH:MM:SS)")
    parser.add_argument("--repo-dir", help="Directory of the git repository")
    parser.add_argument("--file-path", help="Path to the LaTeX file relative to repo root")
    parser.add_argument("--csv-out", help="Path to the output CSV file")
    parser.add_argument("--min-chars", type=int, help="Minimum characters for goal")
    parser.add_argument("--interval-days", type=int, help="Interval in days for each period")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    config = Config.from_env_and_args(args)

    if not os.path.isdir(os.path.join(config.repo_dir, ".git")):
        logger.error("Repo directory '%s' is not a git repository.", config.repo_dir)
        sys.exit(1)

    auto_pull(config)
    check_uncommitted_changes(config)

    records = calculate_progress(config)

    # Write to CSV
    try:
        with open(config.csv_out, "w", newline="", encoding="utf-8") as f:
            if records:
                writer = csv.DictWriter(f, fieldnames=records[0].__dict__.keys())
                writer.writeheader()
                for r in records:
                    writer.writerow(asdict(r))
        logger.info("Saved progress results to %s", config.csv_out)
    except OSError as e:
        logger.error("Failed to write CSV file: %s", e)

    # Print summary to console
    if not records:
        logger.info("No records found.")
        return

    current_record = next((r for r in records if "No" in r.Locked), records[-1])
    diff = current_record.DiffChars
    remaining = max(0, config.min_chars - diff)

    print(
        f"\n🎯 Current Period {current_record.Period} Progress: {diff}/{config.min_chars} chars ",
        end="",
    )
    if remaining > 0:
        print(f"({remaining} remaining!)")
    else:
        print("(Goal met! 🎉)")

    print("-" * 80)
    header = (
        f"{'Period':<6} | {'Start Date':<16} | {'End Date':<16}"
        f" | {'Diff':<6} | {'Target Met':<10} | {'Locked'}"
    )
    print(header)
    print("-" * 80)
    for r in records:
        row = (
            f"{r.Period:<6} | {r.Start:<16} | {r.End:<16}"
            f" | {r.DiffChars:<6} | {r.TargetMet:<10} | {r.Locked}"
        )
        print(row)
    print("-" * 80)


if __name__ == "__main__":
    main()
