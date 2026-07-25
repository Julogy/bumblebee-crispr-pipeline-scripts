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

KRAKEN_DB1="/drives/HDD_22TB_DATA/HDD03_06T_SDE/jspies/kraken2-standard-db"
KRAKEN_DB2="/drives/HDD_22TB_DATA/HDD03_06T_SDE/jspies/bee_db"

KRAKEN_DB="${KRAKEN_DB1},${KRAKEN_DB2}"

for DB in "${KRAKEN_DB1}" "${KRAKEN_DB2}"
do
    if [[ ! -d "${DB}" ]]; then
        echo ""
        echo "FEHLER:"
        echo "Kraken2-Datenbank nicht gefunden:"
        echo "${DB}"
        exit 1
    fi
done

########################################
# Ordner
########################################

REPORT_DIR="${PROJECT_DIR}/kraken_reports"
RESULT_DIR="${PROJECT_DIR}/kraken_results"
LOG_DIR="${PROJECT_DIR}/logs"

########################################
# Funktion
########################################

> "${LOG_DIR}/kraken_summary.txt"

run_kraken() {

    SAMPLE=$1
    TYPE=$2

    FASTQ_DIR="${PROJECT_DIR}/${TYPE}_fastq"

    FASTQ="${FASTQ_DIR}/${SAMPLE}_${TYPE}.fastq.gz"

    REPORT="${REPORT_DIR}/${SAMPLE}_${TYPE}.kreport"

    RESULT="${RESULT_DIR}/${SAMPLE}_${TYPE}.kraken2"

    if [[ ! -f "${FASTQ}" ]]; then
        echo "FEHLT: ${FASTQ}"
        return 1
    fi

    echo ""
    echo "======================================="
    echo "STARTE ${SAMPLE} (${TYPE})"
    echo "======================================="

########################################
# Kraken2
########################################

    echo "===== KRAKEN2 (${TYPE}) ====="

    conda run -n kraken2_env k2 classify \
    --db "${KRAKEN_DB}" \
    --threads ${THREADS} \
    --report "${REPORT}" \
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

    echo -e "${SAMPLE}\t${TYPE}\tclassified:${CLASSIFIED}\tunclassified:${UNCLASSIFIED}" \
        | tee -a "${LOG_DIR}/kraken_summary.txt"

    echo ""
    echo "===== ${SAMPLE} (${TYPE}) FERTIG ====="

}

########################################
# Barcode auswählen
########################################

if [[ "${BARCODE}" == "all" ]]; then

    for FILE in "${PROJECT_DIR}/mapped_fastq/"*_mapped.fastq.gz
    do

        [ -f "${FILE}" ] || continue

        SAMPLE=$(basename "${FILE}" _mapped.fastq.gz)

        run_kraken "${SAMPLE}" mapped
        run_kraken "${SAMPLE}" unmapped

    done

else

    run_kraken "${BARCODE}" mapped
    run_kraken "${BARCODE}" unmapped

fi

########################################
# Fertig
########################################

echo ""
echo "========================================="
echo "PIPELINE FERTIG"
echo "========================================="