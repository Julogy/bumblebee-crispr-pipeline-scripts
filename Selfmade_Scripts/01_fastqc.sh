#!/bin/bash

set -euo pipefail

########################################
# Usage
########################################


if [ "$#" -ne 2 ]; then
    echo ""
    echo "Usage:"
    echo "./01_fastqc.sh <lauf1|lauf2> <barcodeXX|all>"
    echo ""
    echo "Beispiele:"
    echo "./01_fastqc.sh lauf1 barcode13"
    echo "./01_fastqc.sh lauf2 barcode05"
    echo "./01_fastqc.sh lauf1 all"
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
# Eingabedaten
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
# Ausgabe
########################################

FASTQC_DIR="${PROJECT_DIR}/fastqc"
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
        echo "FEHLER:"
        echo "Keine FASTQ-Datei gefunden."
        return 1
    fi

    if [[ ${#FASTQ_FILES[@]} -gt 1 ]]; then
        echo ""
        echo "FEHLER:"
        echo "Mehr als eine FASTQ-Datei gefunden:"
        printf '%s\n' "${FASTQ_FILES[@]}"
        return 1
    fi

    FASTQ="${FASTQ_FILES[0]}"

    echo ""
    echo "======================================="
    echo "STARTE ${SAMPLE}"
    echo "======================================="

########################################
# FastQC
########################################

    echo "===== FASTQC ====="

    conda run -n fastqc_env fastqc \
        -t ${THREADS} \
        -o "${FASTQC_DIR}" \
        "${FASTQ}"

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
# MultiQC
########################################

echo ""
echo "======================================="
echo "MULTIQC"
echo "======================================="

conda run -n multiqc_env multiqc \
    "${FASTQC_DIR}" \
    -o "${MULTIQC_DIR}"

########################################
# Fertig
########################################

echo ""
echo "======================================="
echo "PIPELINE FERTIG"
echo "======================================="