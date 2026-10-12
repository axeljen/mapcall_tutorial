#!/bin/bash -l

#SBATCH -A naiss2026-4-730
#SBATCH -p shared
#SBATCH -c 12
#SBATCH -t 5-00:00:00
#SBATCH -J map-and-call
#SBATCH --mail-type=FAIL
#SBATCH -o ./logs/%x-%j.out
#SBATCH -e ./logs/%x-%j.error

# Load nextflow and modules
ml PDC nextflow singularity

# Path to input file with sample and read information, see readme for details.
INPUT_CSV='sample_sheet_tutorial.csv'

# Path to reference genome (fasta format).
REFERENCE='data/reference/reference_genome.fa.gz'

# Path to reads directory. this argument can be omitted if full paths to reads
# are provided in the input csv (if so, remove the `--reads_dir` argument from
# the command below).
READS_DIR='readlinks'

# Optionally provide a list of scaffols upon which to perform variant calling.
# If not provided, also remove the arguemnt from the command, and the pipeline
# will be run for the entire genome.
SCAFFOLD_LIST='data/reference/scaffold_list.txt'

# Variant caller to use, either 'freebayes' or 'bcftools'.
VARIANT_CALLER='freebayes'

# Chunk size in megabases for parallelizing variant calling. If many samples
# are included, this could be increased a bit to avoid too many jobs getting
# stuck in the queue perhaps.
CHUNK_SIZE=2

# Output directory (created if not present)
OUTDIR='output_tutorial_dsbams_rescaled'

# Run the full pipeline.
# Change to full path to map_and_call/main.nf if run from outside the map_and_call folder.
nextflow run map_and_call/main.nf \
    -profile 'dardel' \
    -resume \
    --input "$INPUT_CSV" \
    --reference "$REFERENCE" \
    --reads_dir "$READS_DIR" \
    --scaffold_list "$SCAFFOLD_LIST" \
    --outdir "$OUTDIR" \
    --slurm_account "$SLURM_JOB_ACCOUNT" \
    --variant_caller "$VARIANT_CALLER" \
    --with_singularity \
    --chunk_size "$CHUNK_SIZE" \
    --downsample_bams \
    --damageprofiler_rescale

##### Some additional, potentially useful flags:

## --skip_premapping_dedup
# By default, a a pcr deduplication step is run first on the raw reads, and then
# again on the mapped reads in the bam file.  in modern data with reasonably low
# levels of duplication rates (say, < ~ 30 %), this is most likely redundant and
# could potentially even lead to over-deduplication and loss of data. So for
# modern, high quality data, this flag is recommended.

## --conda_cachedir
# By default, the conda environments created by the piepline will be stored in
# the .envs directory in the current working directory.  If intending to run
# the pipeline several times, you can save some time and space by setting this
# to a dedicated location that you can then reuse for subseqeunt runs in
# different directories. Then, the environments doesn't need to be recreated.
# See also the NXF_CONDA_CACHEDIR variable above.

## --use_mamba
# If you have a local installation of mamba, this argument will save some time
# when creating the conda environments.  mamba is not available as a module on
# dardel, so the default is to use conda.

## -work-dir
# To save disk-file quota, one may try to write the work directory to a
# temporary folder.  For example: `-work-dir "$SNIC_TMP"/map_and_call`
