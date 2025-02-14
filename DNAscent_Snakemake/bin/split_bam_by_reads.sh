#!/bin/bash

#
# BAM File Splitter and Indexer
#
# Description:
#   This script splits a BAM file into a specified number of chunks and indexes the resulting files.
#   Each chunk retains the BAM header to ensure downstream compatibility.
#
# Usage:
#   ./split_bam_by_chunks.sh <input.bam> <num_chunks> <threads>
#
# Arguments:
#   <input.bam>   - Path to the input BAM file.
#   <num_chunks>  - Number of chunks to split the BAM file into.
#   <threads>     - Number of threads to use for samtools operations.
#
# Requirements:
#   - samtools must be installed and accessible in the environment.
#   - Ensure sufficient disk space for output files.
#
# Author:
#   Chris Sansam
#   2025-02-06
#

set -e  # Exit on error

# Check for required arguments
if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <input.bam> <reads_per_chunk> <threads>"
  exit 1
fi

# Assign arguments to variables
input_bam="$1"
reads_per_chunk="$2"
threads="$3"

# Load samtools module if needed (uncomment for SLURM environments)
# module load samtools

# Get total number of reads in BAM file
total_reads=$(samtools view -c -@ "$threads" "$input_bam")

# Compute number of chunks (Ceiling division)
num_chunks=$(( (total_reads + reads_per_chunk - 1) / reads_per_chunk ))

# Create output directory
base_name=$(basename -s .bam "$input_bam")
output_dir="split_bams/${base_name}"
mkdir -p "$output_dir"

# Extract and store the header
header_file="${output_dir}/${base_name}_header.sam"
samtools view -H "$input_bam" > "$header_file"

# Split BAM file into chunks
echo "Splitting $input_bam into $num_chunks chunks using $threads threads..."
for ((i=0; i<num_chunks; i++)); do
  start=$(( i * reads_per_chunk ))
  output_chunk="${output_dir}/${base_name}_chunk_${i}.bam"

  # Extract reads and combine with the header to create a valid BAM file
  samtools view -@ "$threads" "$input_bam" | awk -v start="$start" -v reads_per_chunk="$reads_per_chunk" \
    'NR > start && NR <= start + reads_per_chunk' | \
    cat "$header_file" - | samtools view -b -@ "$threads" > "$output_chunk"

  echo "Created: $output_chunk"
done

echo "BAM splitting complete: Chunks stored in $output_dir"

# **Index all BAM files using the specified number of threads**
echo "Indexing BAM files with $threads threads..."
for bam_file in "$output_dir"/*.bam; do
  echo "Indexing $bam_file..."
  samtools index -@ "$threads" "$bam_file"
done

echo "All BAM files have been indexed successfully!"
