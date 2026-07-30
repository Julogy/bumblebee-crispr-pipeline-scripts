#!/bin/bash

set -euo pipefail

########################################
# Usage
########################################


if [ "$#" -ne 2 ]; then
    echo ""
    echo "Usage:"
    echo "./01_qc.sh <run1|run2> <barcodeXX|all>"
    echo ""
    echo "Beispiele:"
    echo "./01_qc.sh run1 barcode13"
    echo "./01_qc.sh run2 barcode05"
    echo "./01_qc.sh run1 all"
    exit 1
fi

########################################
# Parameter
########################################

RUN=$1
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
# Eingabedaten
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
# Ausgabe
########################################

MULTIQC_DIR="${PROJECT_DIR}/multiqc"
NANOPLOT_DIR="${PROJECT_DIR}/nanoplot"

########################################
# QC Funktion
########################################



run_qc () {

    SAMPLE=$1

    export _JAVA_OPTIONS="-Xmx16g"

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

    echo ""
    echo "======================================="
    echo "START ${SAMPLE}"
    echo "======================================="


########################################
# NanoPlot
########################################

    echo "===== NANOPLOT ====="

    conda run -n nanoplot_env NanoPlot \
        --fastq "${FASTQ}" \
        --threads ${THREADS} \
        --outdir "${NANOPLOT_DIR}/${SAMPLE}"

    echo ""
    echo "===== ${SAMPLE} FERTIG ====="

}

########################################
# Samples auswählen
########################################

if [[ "${BARCODE}" == "all" ]]; then

    for DIR in "${INPUT_DIR}"/barcode*
    do

        [ -d "${DIR}" ] || continue

        SAMPLE=$(basename "${DIR}")

        run_qc "${SAMPLE}"

    done

else

    run_qc "${BARCODE}"

fi

########################################
# Renaming
########################################

for d in "${SAMPLE}"; do
    mv "${NANOPLOT_DIR}/${SAMPLE}/NanoStats.txt" "${NANOPLOT_DIR}/${SAMPLE}/NanoStats_${SAMPLE}.txt"
done

########################################
# MultiQC
########################################

echo ""
echo "======================================="
echo "MULTIQC"
echo "======================================="

conda run -n multiqc_env multiqc \
    "${NANOPLOT_DIR}" \
    -o "${MULTIQC_DIR}"

########################################
# Fertig
########################################

echo ""
echo "======================================="
echo "PIPELINE FERTIG"
echo "======================================="