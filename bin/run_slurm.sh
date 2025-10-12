#!/bin/bash

#SBATCH --job-name=microphylan
#SBATCH --partition=highmem
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=30-00:00:00
#SBATCH -o job.%j.out
#SBATCH -e job.%j.err
#SBATCH --mail-type=ALL
#SBATCH --mail-user=sodoyo@kemri-wellcome.org

# Set Nextflow work directory to /scratch
export NXF_WORK=/scratch/nextflow_work
mkdir -p $NXF_WORK

# Also set temp dirs for processes/tools
export TMPDIR=/scratch/tmp
export TEMP=/scratch/tmp
export TMP=/scratch/tmp
mkdir -p $TMPDIR

nextflow run main.nf -profile apptainer,test_microphylan,kemri -resume

