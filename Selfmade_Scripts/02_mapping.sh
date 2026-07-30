#!/bin/bash

set -euo pipefail

########################################
# Usage
########################################

if [ "$#" -ne 3 ]; then
    echo ""
    echo "Usage:"
    echo "./02_mapping.sh <run1|run2> <genome.mmi> <barcodeXX|all>"
    echo ""
    echo "Beispiele:"
    echo "./02_mapping.sh run1 /path/to/genome/Bombus.mmi barcode01"
    echo "./02_mapping.sh run2 /path/to/genome/Bombus.mmi all"
    exit 1
fi

########################################
# Parameters
########################################

RUN=$1
GENOME=$2
BARCODE=$3

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
LOG_DIR="${PROJECT_DIR}/logs"

########################################
# Reference check
########################################

if [[ ! -f "${GENOME}" ]]; then
    echo ""
    echo "ERROR:"
    echo "Reference not found:"
    echo "${GENOME}"
    exit 1
fi

########################################
# Mapping Funktion
########################################

run_mapping() {

    SAMPLE=$1

    mapfile -t FASTQ_FILES < <(
    find "${INPUT_DIR}/${SAMPLE}" \
         -maxdepth 1 \
         \( -name "*.fastq" -o -name "*.fastq.gz" \)
    )

    if [[ ${#FASTQ_FILES[@]} -eq 0 ]]; then
        echo ""
        echo "ERROR:"
        echo "No FASTQ found."
        return 1
    fi

    if [[ ${#FASTQ_FILES[@]} -gt 1 ]]; then
        echo ""
        echo "ERROR:"
        echo "More than one FASTQ found:"
        printf '%s\n' "${FASTQ_FILES[@]}"
        return 1
    fi

    FASTQ="${FASTQ_FILES[0]}"

    SORTED_BAM="${BAM_DIR}/${SAMPLE}_aligned_sorted.bam"

    FLAGSTAT="${LOG_DIR}/${SAMPLE}_flagstat.txt"

    if [[ ! -f "${FASTQ}" ]]; then
        echo "MISSING: ${FASTQ}"
        return
    fi

    echo ""
    echo "======================================="
    echo "START ${SAMPLE}"
    echo "======================================="

########################################
# Mapping and Sorting
########################################

    SAM_FILE="${BAM_DIR}/${SAMPLE}.sam"

    echo "===== MINIMAP2 ====="

    conda run -n minimap2_env minimap2 \
        -ax map-ont \
        -Y \
        -t ${THREADS} \
        -R "@RG\tID:${SAMPLE}\tSM:${SAMPLE}\tPL:ONT" \
        "${GENOME}" \
        "${FASTQ}" \
        > "${SAM_FILE}"

    # sometimes the last line was empty
    if [[ -z "$(tail -n 1 "${SAM_FILE}")" ]]; then
        sed -i '${/^$/d;}' "${SAM_FILE}"
    fi

    echo "===== SORT ====="

    conda run -n samtools_env samtools sort \
        -@ ${THREADS} \
        -o "${SORTED_BAM}" \
        "${SAM_FILE}"

    rm -f "${SAM_FILE}"
    
########################################
# BAM Check
########################################

    echo "===== BAM CHECK ====="

    conda run -n samtools_env samtools quickcheck \
        "${SORTED_BAM}"

########################################
# Index
########################################

    echo "===== INDEX ====="

    conda run -n samtools_env samtools index \
        -@ ${THREADS} \
        "${SORTED_BAM}"

########################################
# Flagstat
########################################

    echo "===== FLAGSTAT ====="

    conda run -n samtools_env samtools flagstat \
        -@ ${THREADS} \
        "${SORTED_BAM}" \
        > "${FLAGSTAT}"

########################################
# Summary
########################################

    MAPPED=$(grep " mapped (" "${FLAGSTAT}" | head -1)

    > "${LOG_DIR}/mapping_summary.txt"

    echo -e "${SAMPLE}\t${MAPPED}" \
        | tee -a "${LOG_DIR}/mapping_summary.txt"

    echo ""
    echo "===== ${SAMPLE} Done ====="

}

########################################
# choose Samples 
########################################

if [[ "${BARCODE}" == "all" ]]; then

    for DIR in "${INPUT_DIR}"/barcode*
    do
        [ -d "${DIR}" ] || continue

        SAMPLE=$(basename "${DIR}")

        run_mapping "${SAMPLE}"

    done

else

    run_mapping "${BARCODE}"

fi

########################################
# Done
########################################

echo ""
echo "========================================="
echo "PIPELINE Done"
echo "========================================="