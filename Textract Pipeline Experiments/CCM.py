"""
CCM.py

Tools for analyzing OCR output against ground-truth:
- Character confusion matrix
- OCR error taxonomy (subs / ins / dels / space / punctuation)
"""

from collections import defaultdict, Counter
from dataclasses import dataclass, asdict
from itertools import zip_longest
from typing import Dict, List, Tuple, Iterable, Optional
import difflib
import csv

DELETION_TOKEN = "<DEL>"   # Observed when a true char is missing in OCR
INSERTION_TOKEN = "<INS>"  # True symbol when OCR adds an extra char


@dataclass
class PairErrorStats:
    """Per-pair OCR error statistics."""
    index: int
    truth: str
    ocr: str

    substitutions: int
    insertions: int
    deletions: int

    space_errors: int
    punctuation_errors: int

    cer: float
    exact_match: bool


def is_punctuation(ch: str) -> bool:
    """Return True if character is punctuation (non-alnum, non-space)."""
    return not ch.isalnum() and not ch.isspace()


def align_and_classify(
    truth: str,
    ocr: str,
    confusion_matrix: Dict[str, Counter],
    index: int
) -> PairErrorStats:
    """
    Align a ground-truth string and an OCR string using SequenceMatcher,
    update the confusion matrix, and return detailed error stats for this pair.
    """
    matcher = difflib.SequenceMatcher(None, truth, ocr)
    substitutions = insertions = deletions = 0
    space_errors = punctuation_errors = 0

    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        t_segment = truth[i1:i2]
        o_segment = ocr[j1:j2]

        if tag == "equal":
            # Correct matches: update confusion matrix with identity mapping
            for t_ch, o_ch in zip(t_segment, o_segment):
                confusion_matrix[t_ch][o_ch] += 1

        elif tag == "replace":
            # Character-by-character substitutions (and possible length mismatch)
            for t_ch, o_ch in zip_longest(t_segment, o_segment, fillvalue=None):
                if t_ch is not None and o_ch is not None:
                    # Substitution
                    substitutions += 1
                    confusion_matrix[t_ch][o_ch] += 1

                    # Space-related errors
                    if t_ch.isspace() != o_ch.isspace():
                        space_errors += 1

                    # Punctuation-related errors
                    if is_punctuation(t_ch) or is_punctuation(o_ch):
                        punctuation_errors += 1

                elif t_ch is not None and o_ch is None:
                    # Deletion (truth char missing in OCR)
                    deletions += 1
                    confusion_matrix[t_ch][DELETION_TOKEN] += 1

                    if t_ch.isspace():
                        space_errors += 1
                    if is_punctuation(t_ch):
                        punctuation_errors += 1

                elif t_ch is None and o_ch is not None:
                    # Insertion (extra OCR char)
                    insertions += 1
                    confusion_matrix[INSERTION_TOKEN][o_ch] += 1

                    if o_ch.isspace():
                        space_errors += 1
                    if is_punctuation(o_ch):
                        punctuation_errors += 1

        elif tag == "delete":
            # Truth chars missing entirely in OCR
            for t_ch in t_segment:
                deletions += 1
                confusion_matrix[t_ch][DELETION_TOKEN] += 1

                if t_ch.isspace():
                    space_errors += 1
                if is_punctuation(t_ch):
                    punctuation_errors += 1

        elif tag == "insert":
            # Extra chars in OCR
            for o_ch in o_segment:
                insertions += 1
                confusion_matrix[INSERTION_TOKEN][o_ch] += 1

                if o_ch.isspace():
                    space_errors += 1
                if is_punctuation(o_ch):
                    punctuation_errors += 1

    # Character Error Rate (CER)
    truth_len = len(truth)
    cer = (substitutions + insertions + deletions) / truth_len if truth_len > 0 else 0.0

    return PairErrorStats(
        index=index,
        truth=truth,
        ocr=ocr,
        substitutions=substitutions,
        insertions=insertions,
        deletions=deletions,
        space_errors=space_errors,
        punctuation_errors=punctuation_errors,
        cer=cer,
        exact_match=(truth == ocr),
    )


def analyze_ocr_pairs(
    truths: Iterable[str],
    ocrs: Iterable[str]
) -> Tuple[Dict[str, Counter], List[PairErrorStats], Dict[str, float]]:
    """
    Analyze lists of ground-truth and OCR strings.

    Returns:
      confusion_matrix: dict true_char -> Counter(ocr_char -> count)
      per_pair_stats: list of PairErrorStats for each pair
      summary: aggregate taxonomy with global error rates
    """
    truths = list(truths)
    ocrs = list(ocrs)
    if len(truths) != len(ocrs):
        raise ValueError("truths and ocrs must have the same length")

    confusion_matrix: Dict[str, Counter] = defaultdict(Counter)
    per_pair_stats: List[PairErrorStats] = []

    for idx, (t, o) in enumerate(zip(truths, ocrs)):
        stats = align_and_classify(t, o, confusion_matrix, index=idx)
        per_pair_stats.append(stats)

    # Aggregate summary
    total_subs = sum(s.substitutions for s in per_pair_stats)
    total_ins = sum(s.insertions for s in per_pair_stats)
    total_del = sum(s.deletions for s in per_pair_stats)
    total_space = sum(s.space_errors for s in per_pair_stats)
    total_punct = sum(s.punctuation_errors for s in per_pair_stats)
    total_truth_chars = sum(len(s.truth) for s in per_pair_stats)

    global_cer = (
        (total_subs + total_ins + total_del) / total_truth_chars
        if total_truth_chars > 0 else 0.0
    )

    summary = {
        "total_pairs": len(per_pair_stats),
        "total_truth_chars": total_truth_chars,
        "total_substitutions": total_subs,
        "total_insertions": total_ins,
        "total_deletions": total_del,
        "total_space_errors": total_space,
        "total_punctuation_errors": total_punct,
        "global_CER": global_cer,
        "exact_match_ratio": sum(s.exact_match for s in per_pair_stats) / len(per_pair_stats)
        if per_pair_stats else 0.0,
    }

    return confusion_matrix, per_pair_stats, summary


def confusion_matrix_to_sorted_pairs(
    confusion_matrix: Dict[str, Counter],
    min_count: int = 1
) -> List[Tuple[str, str, int]]:
    """
    Flatten confusion matrix into a list of (truth_char, ocr_char, count), sorted
    by descending count. Filters out entries with count < min_count.
    """
    rows: List[Tuple[str, str, int]] = []
    for t_ch, counter in confusion_matrix.items():
        for o_ch, cnt in counter.items():
            if cnt >= min_count:
                rows.append((t_ch, o_ch, cnt))

    rows.sort(key=lambda x: x[2], reverse=True)
    return rows


def load_columns_from_csv(
    path: str,
    truth_column: str,
    ocr_column: str,
    encoding: str = "utf-8"
) -> Tuple[List[str], List[str]]:
    """
    Load two columns from a CSV: ground-truth and OCR strings.

    Returns:
      truths, ocrs as lists of strings
    """
    truths: List[str] = []
    ocrs: List[str] = []

    with open(path, "r", encoding=encoding, newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            truths.append(row[truth_column])
            ocrs.append(row[ocr_column])

    return truths, ocrs


# Optional: helper to convert per-pair stats to a list of dicts (e.g., for pandas)
def per_pair_stats_to_dicts(per_pair_stats: List[PairErrorStats]) -> List[dict]:
    """
    Convert list of PairErrorStats to list of dicts (handy for pandas DataFrame).
    """
    return [asdict(s) for s in per_pair_stats]


if __name__ == "__main__":
    # Minimal example usage
    truths = [
        "ABC123",
        "Hello, world!",
        "2025-12-01",
        "Line with spaces",
    ]

    ocrs = [
        "ABC12B",          # B instead of 3
        "Hello world",     # missing comma
        "2025-12-O1",      # O instead of 0
        "Linewith  spaces" # space issues
    ]

    cm, pair_stats, summary = analyze_ocr_pairs(truths, ocrs)

    print("=== Summary ===")
    for k, v in summary.items():
        print(f"{k}: {v}")

    print("\n=== Top Confusions (truth_char -> ocr_char: count) ===")
    for t_ch, o_ch, cnt in confusion_matrix_to_sorted_pairs(cm, min_count=1):
        print(repr(t_ch), "->", repr(o_ch), ":", cnt)

    print("\n=== First pair detailed stats ===")
    if pair_stats:
        print(pair_stats[0])



from CCM import (
    load_columns_from_csv,
    analyze_ocr_pairs,
    confusion_matrix_to_sorted_pairs,
    per_pair_stats_to_dicts,
)

truths, ocrs = load_columns_from_csv("rows_with_no_equality.csv", "AWS_Value", "Manual_Value")

confusion_matrix, per_pair_stats, summary = analyze_ocr_pairs(truths, ocrs)

print(summary)  # global CER, counts, etc.

top_confusions = confusion_matrix_to_sorted_pairs(confusion_matrix, min_count=5)
for t_ch, o_ch, cnt in top_confusions[:30]:
    print(repr(t_ch), "->", repr(o_ch), ":", cnt)