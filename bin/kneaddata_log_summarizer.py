#!/usr/bin/env python
import re, csv, argparse
from pathlib import Path

def parse_kneaddata_log(log_path):
    stats = {
        "sample_id": Path(log_path).stem,
        "input_pairs": 0,
        "paired_surviving": 0,
        "forward_orphan": 0,
        "reverse_orphan": 0,
        "after_trimming_reads": 0,
        "percent_after_trimming": 0.0,
        "after_hostremoval_reads": 0,
        "percent_host_removed": 0.0,
        "final_percent_retained": 0.0,
    }

    with open(log_path, "r", errors="ignore") as f:
        text = f.read()

    # --- INPUT READS ---
    m = re.search(r"READ COUNT:\s*raw\s*pair1.*?:\s*([\d,\.]+)", text, re.IGNORECASE)
    if not m:
        m = re.search(r"READ COUNT:\s*raw\s*pair2.*?:\s*([\d,\.]+)", text, re.IGNORECASE)
    if m:
        stats["input_pairs"] = int(float(m.group(1).replace(",", "")))

    # --- TRIMMOMATIC SECTION ---
    def extract_count(label):
        m = re.search(rf"{label}\s*:\s*([\d,\.]+)", text, re.IGNORECASE)
        return int(float(m.group(1).replace(",", ""))) if m else 0

    stats["paired_surviving"] = extract_count("Both Surviving")
    stats["forward_orphan"] = extract_count("Forward Only Surviving")
    stats["reverse_orphan"] = extract_count("Reverse Only Surviving")

    stats["after_trimming_reads"] = (
        stats["paired_surviving"] * 2 +
        stats["forward_orphan"] +
        stats["reverse_orphan"]
    )

    if stats["input_pairs"] > 0:
        stats["percent_after_trimming"] = round(
            (stats["after_trimming_reads"] / (stats["input_pairs"] * 2)) * 100, 2
        )

    # --- HOST REMOVAL ---
    final_counts = {}
    for name in ["pair1", "pair2", "orphan1", "orphan2"]:
        m = re.search(rf"READ COUNT:\s*final\s+{name}.*?:\s*([\d,\.]+)", text, re.IGNORECASE)
        final_counts[name] = int(float(m.group(1).replace(",", ""))) if m else 0

    stats["after_hostremoval_reads"] = (
        final_counts["pair1"] + final_counts["pair2"] +
        final_counts["orphan1"] + final_counts["orphan2"]
    )

    # --- PERCENTAGES ---
    if stats["after_trimming_reads"] > 0:
        stats["percent_host_removed"] = round(
            100 * (1 - stats["after_hostremoval_reads"] / stats["after_trimming_reads"]), 2
        )

    if stats["input_pairs"] > 0:
        stats["final_percent_retained"] = round(
            100 * (stats["after_hostremoval_reads"] / (stats["input_pairs"] * 2)), 2
        )

    return stats


def main():
    parser = argparse.ArgumentParser(description="Summarize KneadData log files into a single CSV.")
    parser.add_argument("-i", "--input", nargs="+", required=True, help="Input one or more KneadData log files.")
    parser.add_argument("-o", "--output", default="kneaddata_summary.csv", help="Output CSV filename.")
    args = parser.parse_args()

    fieldnames = [
        "sample_id",
        "input_pairs",
        "paired_surviving",
        "forward_orphan",
        "reverse_orphan",
        "after_trimming_reads",
        "percent_after_trimming",
        "after_hostremoval_reads",
        "percent_host_removed",
        "final_percent_retained",
    ]

    all_stats = []
    for log_path in args.input:
        all_stats.append(parse_kneaddata_log(log_path))

    with open(args.output, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(all_stats)

    print(f"[✅] Summary written to: {args.output}")


if __name__ == "__main__":
    main()
