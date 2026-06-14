"""Tests for progress_tracker.py — pure functions only (no git/mocking needed)."""

import datetime
from argparse import Namespace
from dataclasses import asdict

from progress_tracker import (
    Config,
    ProgressRecord,
    build_json_result,
    char_diff,
    has_uncommitted_changes,
    parse_args,
    strip_latex_comments,
)


# ── strip_latex_comments ──────────────────────────────────────────────────────


class TestStripLatexComments:
    def test_removes_simple_comment(self):
        assert strip_latex_comments("hello% world") == "hello"

    def test_keeps_text_before_comment(self):
        assert strip_latex_comments(r"\section{Intro}% label") == r"\section{Intro}"

    def test_preserves_escaped_percent(self):
        assert strip_latex_comments(r"100\% done") == r"100\% done"

    def test_removes_comment_after_escaped_percent(self):
        assert strip_latex_comments(r"100\% done% note") == r"100\% done"

    def test_multiple_lines(self):
        text = "line1%comment1\nline2%comment2\nline3"
        expected = "line1\nline2\nline3"
        assert strip_latex_comments(text) == expected

    def test_empty_string(self):
        assert strip_latex_comments("") == ""

    def test_only_comment_line_is_removed(self):
        assert strip_latex_comments("% just a comment") == ""

    def test_whitespace_only_line_after_strip_is_removed(self):
        text = "real text\n  % indented comment\nmore text"
        expected = "real text\nmore text"
        assert strip_latex_comments(text) == expected

    def test_no_comment_preserves_text(self):
        assert strip_latex_comments("plain text") == "plain text"

    def test_multiple_percent_signs(self):
        # In LaTeX only \% is escaped, so %% starts a comment at the first %
        assert strip_latex_comments(r"a%%b%comment") == "a"


# ── char_diff ─────────────────────────────────────────────────────────────────


class TestCharDiff:
    def test_identical_strings_no_diff(self):
        assert char_diff("hello", "hello") == 0

    def test_empty_strings_no_diff(self):
        assert char_diff("", "") == 0

    def test_addition_counts_inserted_chars(self):
        assert char_diff("", "abc") == 3

    def test_deletion_counts_removed_chars(self):
        assert char_diff("abc", "") == 3

    def test_replacement_counts_both_sides(self):
        assert char_diff("abc", "xyz") == 6  # 3 deleted + 3 inserted

    def test_partial_change(self):
        diff = char_diff("hello world", "hello there")
        assert diff > 0
        # "world" (5) replaced by "there" (5) = 10

    def test_strips_comments_before_diff(self):
        text1 = r"\section{Hello}% old comment"
        text2 = r"\section{Hello}% new comment"
        assert char_diff(text1, text2) == 0  # comments stripped, content same

    def test_latex_content_changes(self):
        text1 = r"\section{Hello}"
        text2 = r"\section{Hello}\subsection{World}"
        assert char_diff(text1, text2) > 0


# ── ProgressRecord ────────────────────────────────────────────────────────────


class TestProgressRecord:
    def test_dataclass_fields(self):
        record = ProgressRecord(
            Period=1,
            Start="2024-01-01 00:00",
            End="2024-01-08 00:00",
            DiffChars=500,
            CommitCount=3,
            TargetMet="No",
            Locked="Yes",
        )
        assert record.Period == 1
        assert record.DiffChars == 500
        assert record.CommitCount == 3
        assert record.TargetMet == "No"

    def test_asdict_roundtrip(self):
        record = ProgressRecord(1, "s", "e", 100, 2, "Yes", "No")
        d = asdict(record)
        assert d["Period"] == 1
        assert d["DiffChars"] == 100


# ── Config ────────────────────────────────────────────────────────────────────


class TestConfig:
    def test_from_env_and_args_returns_config(self):
        args = Namespace(
            start_date="2024-01-01 00:00:00",
            repo_dir="/tmp",
            file_path="main.tex",
            csv_out="out.csv",
            min_chars=500,
            interval_days=14,
        )
        config = Config.from_env_and_args(args)
        assert isinstance(config, Config)
        assert config.start_date == datetime.datetime(2024, 1, 1, 0, 0, 0)
        assert config.file_path == "main.tex"
        assert config.min_chars == 500
        assert config.interval_days == 14
        assert config.csv_out == "out.csv"


# ── build_json_result ─────────────────────────────────────────────────────────


class TestBuildJsonResult:
    def test_structure_with_current_period(self):
        config = Config(
            start_date=datetime.datetime(2024, 1, 1),
            repo_dir="/repo",
            min_chars=1000,
        )
        records = [
            ProgressRecord(1, "2024-01-01", "2024-01-08", 600, 2, "No", "No (Current)"),
            ProgressRecord(2, "2024-01-08", "2024-01-15", 1200, 5, "Yes", "Yes"),
        ]
        result = build_json_result(config, records, ["warning 1"])

        assert result["repo_dir"] == "/repo"
        assert result["min_chars"] == 1000
        assert result["interval_days"] == 7
        assert result["has_uncommitted_changes"] is False
        assert result["warnings"] == ["warning 1"]
        assert len(result["records"]) == 2

        # Current period info
        current = result["current_period"]
        assert current["period"] == 1
        assert current["diff_chars"] == 600
        assert current["remaining_chars"] == 400
        assert current["target_met"] is False
        assert current["locked"] is False

    def test_structure_with_all_locked(self):
        config = Config(
            start_date=datetime.datetime(2024, 1, 1),
            repo_dir="/repo",
            min_chars=1000,
        )
        records = [
            ProgressRecord(1, "2024-01-01", "2024-01-08", 1500, 3, "Yes", "Yes"),
        ]
        result = build_json_result(config, records, [])

        # Falls back to last record when none is current
        current = result["current_period"]
        assert current["period"] == 1
        assert current["target_met"] is True
        assert current["locked"] is True

    def test_empty_records(self):
        config = Config(
            start_date=datetime.datetime(2024, 1, 1),
            repo_dir="/repo",
            min_chars=1000,
        )
        result = build_json_result(config, [], [])
        assert result["current_period"] is None
        assert result["records"] == []

    def test_remaining_chars_never_negative(self):
        config = Config(
            start_date=datetime.datetime(2024, 1, 1),
            repo_dir="/repo",
            min_chars=1000,
        )
        records = [
            ProgressRecord(1, "2024-01-01", "2024-01-08", 2000, 5, "Yes", "No (Current)"),
        ]
        result = build_json_result(config, records, [])
        assert result["current_period"]["remaining_chars"] == 0  # not negative


# ── parse_args ────────────────────────────────────────────────────────────────


class TestParseArgs:
    def test_defaults(self, monkeypatch):
        monkeypatch.setattr("sys.argv", ["progress_tracker.py"])
        args = parse_args()
        assert args.start_date is None
        assert args.repo_dir is None
        assert args.file_path is None
        assert args.csv_out is None
        assert args.min_chars is None
        assert args.interval_days is None
        assert args.json_output is False
        assert args.no_auto_pull is False

    def test_json_flag(self, monkeypatch):
        monkeypatch.setattr("sys.argv", ["progress_tracker.py", "--json"])
        args = parse_args()
        assert args.json_output is True

    def test_no_auto_pull_flag(self, monkeypatch):
        monkeypatch.setattr("sys.argv", ["progress_tracker.py", "--no-auto-pull"])
        args = parse_args()
        assert args.no_auto_pull is True
