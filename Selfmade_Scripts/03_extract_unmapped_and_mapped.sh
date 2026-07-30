#!/bin/bash

set -euo pipefail

########################################
# Usage
########################################

if [ "$#" -ne 2 ]; then
    echo ""
    echo "Usage:"
    echo "./03_extract_unmapped.sh <run1|run2> <barcodeXX|all>"
    echo ""
    echo "Beispiele:"
    echo "./03_extract_unmapped.sh run1 barcode13"
    echo "./03_extract_unmapped.sh run2 barcode05"
    echo "./03_extract_unmapped.sh run1 all"
    exit 1
fi

########################################
# Parameters
########################################

RUN=$1
BARCODE=$2

########################################
# Initialising Conda
########################################

source "$(conda info --base)/etc/profile.d/conda.sh"

########################################
# Settings
########################################

THREADS=20

########################################
# Input
########################################

BASE_INPUT="/path/to/SequencingData"

case "${RUN}" in
    run1)
        INPUT_DIR="${BASE_INPUT}/Run_1"
        PROJECT_DIR="/path/to/Project1"
        ;;
    run2)
        INPUT_DIR="${BASE_INPUT}/Run_2"
        PROJECT_DIR="/path/to/Project2"
        ;;
    *)
        echo "invalid run."
        exit 1
        ;;
esac

########################################
# Output
########################################

BAM_DIR="${PROJECT_DIR}/bams"
UNMAPPED_BAM_DIR="${PROJECT_DIR}/unmapped_bams"
UNMAPPED_FASTQ_DIR="${PROJECT_DIR}/unmapped_fastq"
MAPPED_BAM_DIR="${PROJECT_DIR}/mapped_bams"
MAPPED_FASTQ_DIR="${PROJECT_DIR}/mapped_fastq"
LOG_DIR="${PROJECT_DIR}/logs"

########################################
# Funktion
########################################

extract_unmapped() {

    SAMPLE=$1

    SORTED_BAM="${BAM_DIR}/${SAMPLE}_aligned_sorted.bam"

    UNMAPPED_BAM="${UNMAPPED_BAM_DIR}/${SAMPLE}_unmapped.bam"
    MAPPED_BAM="${MAPPED_BAM_DIR}/${SAMPLE}_mapped.bam"

    UNMAPPED_FASTQ="${UNMAPPED_FASTQ_DIR}/${SAMPLE}_unmapped.fastq"
    MAPPED_FASTQ="${MAPPED_FASTQ_DIR}/${SAMPLE}_mapped.fastq"

    if [[ ! -f "${SORTED_BAM}" ]]; then
        echo "MISSING: ${SORTED_BAM}"
        return
    fi

    echo ""
    echo "======================================="
    echo "START ${SAMPLE}"
    echo "======================================="

########################################
# Unmapped BAM
########################################

    echo "===== UNMAPPED BAM ====="

    conda run -n samtools_env samtools view \
        -b \
        -f 4 \
        -F 0x900 \
        -@ ${THREADS} \
        "${SORTED_BAM}" \
        -o "${UNMAPPED_BAM}"

########################################
# Mapped BAM
########################################

    echo "===== MAPPED BAM ====="

    conda run -n samtools_env samtools view \
        -b \
        -F 4 \
        -F 0x900 \
        -@ ${THREADS} \
        "${SORTED_BAM}" \
        -o "${MAPPED_BAM}"

########################################
# Read Count
########################################

    echo "===== READ COUNT ====="

    READS_UNMAPPED=$(conda run -n samtools_env samtools view \
        -c \
        "${UNMAPPED_BAM}")

    READS_MAPPED=$(conda run -n samtools_env samtools view \
        -c \
        "${MAPPED_BAM}")

    > "${LOG_DIR}/unmapped_read_counts.txt"
    > "${LOG_DIR}/mapped_read_counts.txt"

    echo -e "${SAMPLE}\t${READS_UNMAPPED}" \
        | tee -a "${LOG_DIR}/unmapped_read_counts.txt"

    echo -e "${SAMPLE}\t${READS_MAPPED}" \
        | tee -a "${LOG_DIR}/mapped_read_counts.txt"

########################################
# BAM -> FASTQ
########################################

    echo "===== BAM TO FASTQ (UNMAPPED) ====="

    conda run -n samtools_env samtools fastq \
        -@ "${THREADS}" \
        -T '*' \
        "${UNMAPPED_BAM}" \
    | gzip > "${UNMAPPED_FASTQ}.gz"

    zcat "${UNMAPPED_FASTQ}.gz" \
    | sed '${/^$/d;}' \
    | gzip > "${UNMAPPED_FASTQ}.fixed.gz"

    mv "${UNMAPPED_FASTQ}.fixed.gz" "${UNMAPPED_FASTQ}.gz"

    echo "===== BAM TO FASTQ (MAPPED) ====="

    conda run -n samtools_env samtools fastq \
        -@ "${THREADS}" \
        -T '*' \
        "${MAPPED_BAM}" \
    | gzip > "${MAPPED_FASTQ}.gz"

    zcat "${MAPPED_FASTQ}.gz" \
    | sed '${/^$/d;}' \
    | gzip > "${MAPPED_FASTQ}.fixed.gz"

    mv "${MAPPED_FASTQ}.fixed.gz" "${MAPPED_FASTQ}.gz"

########################################
# Controll
########################################

    if [[ ! -s "${UNMAPPED_FASTQ}.gz" ]]; then
        echo "ERROR: UNMAPPED FASTQ was not created."
        return 1
    fi

    if [[ ! -s "${MAPPED_FASTQ}.gz" ]]; then
        echo "ERROR: MAPPED FASTQ was not created."
        return 1
    fi

    echo ""
    echo "===== ${SAMPLE} Done ====="

}

########################################
# Choose Barcode
########################################

if [[ "${BARCODE}" == "all" ]]; then

    for BAM in "${BAM_DIR}"/*_aligned_sorted.bam
    do

        [ -f "${BAM}" ] || continue

        SAMPLE=$(basename "${BAM}" _aligned_sorted.bam)

        extract_unmapped "${SAMPLE}"

    done

else

    extract_unmapped "${BARCODE}"

fi

########################################
# Done
########################################

echo ""
echo "========================================="
echo "PIPELINE Done"
echo "========================================="