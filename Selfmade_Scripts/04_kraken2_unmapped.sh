#!/bin/bash

set -euo pipefail

########################################
# Usage
########################################

if [ "$#" -ne 2 ]; then
    echo ""
    echo "Usage:"
    echo "./04_kraken2.sh <lauf1|lauf2> <barcodeXX|all>"
    echo ""
    echo "Beispiele:"
    echo "./04_kraken2.sh lauf1 barcode13"
    echo "./04_kraken2.sh lauf2 barcode05"
    echo "./04_kraken2.sh lauf1 all"
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
# Kraken Datenbank
########################################

KRAKEN_DB="/drives/HDD_22TB_DATA/HDD03_06T_SDE/jspies/kraken_db"

if [[ ! -d "${KRAKEN_DB}" ]]; then
    echo ""
    echo "FEHLER:"
    echo "Kraken2-Datenbank nicht gefunden:"
    echo "${KRAKEN_DB}"
    exit 1
fi

########################################
# Ordner
########################################

FASTQ_DIR="${PROJECT_DIR}/unmapped_fastq"

REPORT_DIR="${PROJECT_DIR}/kraken_reports"

RESULT_DIR="${PROJECT_DIR}/kraken_results"

LOG_DIR="${PROJECT_DIR}/logs"

########################################
# Funktion
########################################

> "${LOG_DIR}/kraken_summary.txt"

run_kraken() {

    SAMPLE=$1

    FASTQ="${FASTQ_DIR}/${SAMPLE}_unmapped.fastq.gz"

    REPORT="${REPORT_DIR}/${SAMPLE}_unmapped.kreport"

    RESULT="${RESULT_DIR}/${SAMPLE}.kraken2"

    if [[ ! -f "${FASTQ}" ]]; then
        echo "FEHLT: ${FASTQ}"
        return 1
    fi

    echo ""
    echo "======================================="
    echo "STARTE ${SAMPLE}"
    echo "======================================="

########################################
# Kraken2
########################################

    echo "===== KRAKEN2 ====="

    conda run -n kraken2_env kraken2 \
        --db "${KRAKEN_DB}" \
        --threads ${THREADS} \
        --report "${REPORT}" \
        --report-minimizer-data \
        --gzip-compressed \
        "${FASTQ}" \
        > "${RESULT}"

########################################
# Kontrolle
########################################

    if [[ ! -s "${RESULT}" ]]; then
        echo "FEHLER: Kraken2-Ausgabe wurde nicht erstellt."
        return 1
    fi

########################################
# Statistik
########################################

    CLASSIFIED=$(grep "^C" "${RESULT}" | wc -l)
    UNCLASSIFIED=$(grep "^U" "${RESULT}" | wc -l)

    echo -e "${SAMPLE}\tclassified:${CLASSIFIED}\tunclassified:${UNCLASSIFIED}" \
        | tee -a "${LOG_DIR}/kraken_summary.txt"

    echo ""
    echo "===== ${SAMPLE} FERTIG ====="

}

########################################
# Barcode auswählen
########################################

if [[ "${BARCODE}" == "all" ]]; then

    for FILE in "${FASTQ_DIR}"/*_unmapped.fastq.gz
    do

        [ -f "${FILE}" ] || continue

        SAMPLE=$(basename "${FILE}" _unmapped.fastq.gz)

        run_kraken "${SAMPLE}"

    done

else

    run_kraken "${BARCODE}"

fi

########################################
# Fertig
########################################

echo ""
echo "========================================="
echo "PIPELINE FERTIG"
echo "========================================="