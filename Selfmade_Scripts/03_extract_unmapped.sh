#!/bin/bash

set -euo pipefail

########################################
# Usage
########################################

if [ "$#" -ne 2 ]; then
    echo ""
    echo "Usage:"
    echo "./03_extract_unmapped.sh <lauf1|lauf2> <barcodeXX|all>"
    echo ""
    echo "Beispiele:"
    echo "./03_extract_unmapped.sh lauf1 barcode13"
    echo "./03_extract_unmapped.sh lauf2 barcode05"
    echo "./03_extract_unmapped.sh lauf1 all"
    exit 1
fi

########################################
# Parameter
########################################

LAUF=$1
BARCODE=$2

########################################
# Conda initialisieren
########################################

source "$(conda info --base)/etc/profile.d/conda.sh"

########################################
# Einstellungen
########################################

THREADS=20

########################################
# Projektverzeichnis
########################################

BASE_INPUT="/drives/HDD_22TB_DATA/HDD03_06T_SDE/jspies/Sequenzierdaten"

case "${LAUF}" in
    lauf1)
        INPUT_DIR="${BASE_INPUT}/Lauf_1"
        PROJECT_DIR="/drives/HDD_22TB_DATA/HDD03_06T_SDE/jspies/Tom_Pipeline_Wildbiene1"
        ;;
    lauf2)
        INPUT_DIR="${BASE_INPUT}/Lauf_2"
        PROJECT_DIR="/drives/HDD_22TB_DATA/HDD03_06T_SDE/jspies/Tom_Pipeline_Wildbiene2"
        ;;
    *)
        echo "Ungültiger Lauf."
        exit 1
        ;;
esac

########################################
# Ordner
########################################

BAM_DIR="${PROJECT_DIR}/bams"
UNMAPPED_BAM_DIR="${PROJECT_DIR}/unmapped_bams"
UNMAPPED_FASTQ_DIR="${PROJECT_DIR}/unmapped_fastq"
LOG_DIR="${PROJECT_DIR}/logs"

########################################
# Funktion
########################################

extract_unmapped() {

    SAMPLE=$1

    SORTED_BAM="${BAM_DIR}/${SAMPLE}_aligned_sorted.bam"

    UNMAPPED_BAM="${UNMAPPED_BAM_DIR}/${SAMPLE}_unmapped.bam"

    UNMAPPED_FASTQ="${UNMAPPED_FASTQ_DIR}/${SAMPLE}_unmapped.fastq"

    if [[ ! -f "${SORTED_BAM}" ]]; then
        echo "FEHLT: ${SORTED_BAM}"
        return
    fi

    echo ""
    echo "======================================="
    echo "STARTE ${SAMPLE}"
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
# Anzahl Reads
########################################

    echo "===== READ COUNT ====="

    READS=$(conda run -n samtools_env samtools view \
        -c \
        "${UNMAPPED_BAM}")

    > "${LOG_DIR}/unmapped_read_counts.txt"

    echo -e "${SAMPLE}\t${READS}" \
        | tee -a "${LOG_DIR}/unmapped_read_counts.txt"

########################################
# BAM -> FASTQ
########################################

    echo "===== BAM TO FASTQ ====="

    conda run -n samtools_env samtools fastq \
        -@ "${THREADS}" \
        -T '*' \
        "${UNMAPPED_BAM}" \
    | gzip > "${UNMAPPED_FASTQ}.gz"

    zcat "${UNMAPPED_FASTQ}.gz" \
    | sed '${/^$/d;}' \
    | gzip > "${UNMAPPED_FASTQ}.fixed.gz"

    mv "${UNMAPPED_FASTQ}.fixed.gz" "${UNMAPPED_FASTQ}.gz"
    
########################################
# Kontrolle
########################################

    if [[ ! -s "${UNMAPPED_FASTQ}.gz" ]]; then
        echo "FEHLER: FASTQ wurde nicht erstellt."
        return 1
    fi

    echo ""
    echo "===== ${SAMPLE} FERTIG ====="

}

########################################
# Barcode auswählen
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
# Fertig
########################################

echo ""
echo "========================================="
echo "PIPELINE FERTIG"
echo "========================================="