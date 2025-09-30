#!/usr/bin/env python3
"""
generate_sample_sheet.py

Generate a CSV sample sheet from paired-end FASTQ files in a directory.

Features:
- Automatically derives sample IDs from filenames ending with _1/_2.
- Optional: use a mapping CSV to specify custom sample IDs.
- Only includes complete pairs (R1 and R2).
- Recursively searches subdirectories.
- Prevents mixing R1/R2 from different directories.
- Default ID is the basename (without _1/_2), but uniqueness is enforced by full path.

Usage:
    # Automatic IDs
    python generate_sample_sheet.py -d /path/to/fastq -o sample_sheet.csv

    # With custom mapping CSV
    python generate_sample_sheet.py -d /path/to/fastq -o sample_sheet.csv -m mapping.csv

Mapping CSV format (if using -m):
    sample_id,filename_prefix
"""

import csv
from pathlib import Path
import argparse
import sys

def load_mapping(mapping_csv: str) -> dict:
    """Load custom sample ID mapping from CSV."""
    mapping = {}
    try:
        with open(mapping_csv, newline="") as csvfile:
            reader = csv.DictReader(csvfile)
            if "sample_id" not in reader.fieldnames or "filename_prefix" not in reader.fieldnames:
                raise ValueError("Mapping CSV must have columns: sample_id, filename_prefix")
            for row in reader:
                prefix = row.get("filename_prefix")
                sample_id = row.get("sample_id")
                if prefix and sample_id:
                    mapping[prefix] = sample_id
    except Exception as e:
        print(f"Error reading mapping CSV '{mapping_csv}': {e}")
        sys.exit(1)
    return mapping

def generate_sample_sheet(directory: str, output_csv: str, mapping_csv: str = None) -> None:
    """Generate a CSV sample sheet for paired-end FASTQ files."""
    directory = Path(directory).resolve()
    if not directory.is_dir():
        print(f"Error: {directory} is not a directory.")
        sys.exit(1)

    # Recursively collect all fastq.gz files
    files = sorted(directory.rglob("*.fastq.gz"))
    if not files:
        print(f"No FASTQ files found in {directory} or its subdirectories.")
        sys.exit(1)

    custom_ids = load_mapping(mapping_csv) if mapping_csv else {}

    samples = {}
    for f in files:
        # Strip extensions
        name = f.name.replace(".fastq.gz", "")

        if name.endswith("_1"):
            prefix_key = str(f.relative_to(directory).with_suffix("").with_suffix(""))[:-2]  # safe unique key
            basename_prefix = name[:-2]  # for display in 'id'
            rtype = "r1"
        elif name.endswith("_2"):
            prefix_key = str(f.relative_to(directory).with_suffix("").with_suffix(""))[:-2]
            basename_prefix = name[:-2]
            rtype = "r2"
        else:
            continue  # skip non-matching files

        # Map to custom ID if available, otherwise use basename
        sample_id = custom_ids.get(basename_prefix, basename_prefix)

        if prefix_key not in samples:
            samples[prefix_key] = {"id": sample_id, "r1": None, "r2": None}
        samples[prefix_key][rtype] = str(f.resolve())

    # Keep only complete pairs
    paired_samples = {k: v for k, v in samples.items() if v["r1"] and v["r2"]}
    skipped = len(samples) - len(paired_samples)
    if skipped > 0:
        print(f"Warning: {skipped} sample(s) skipped due to incomplete pairs.")

    # Write CSV
    with open(output_csv, "w", newline="") as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(["id", "r1", "r2"])
        for key in sorted(paired_samples):
            sample = paired_samples[key]
            writer.writerow([sample["id"], sample["r1"], sample["r2"]])

    print(f"Sample sheet written to {output_csv}. Total samples: {len(paired_samples)}")

def main():
    parser = argparse.ArgumentParser(
        description="Generate a CSV sample sheet for paired FASTQ files.",
        formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument("-d", "--directory", required=True, help="Directory containing FASTQ files")
    parser.add_argument("-o", "--output", required=True, help="Path to output CSV file")
    parser.add_argument(
        "-m", "--mapping",
        required=False,
        help="Optional CSV to specify custom sample IDs (columns: sample_id, filename_prefix)"
    )

    args = parser.parse_args()
    generate_sample_sheet(args.directory, args.output, args.mapping)

if __name__ == "__main__":
    main()
