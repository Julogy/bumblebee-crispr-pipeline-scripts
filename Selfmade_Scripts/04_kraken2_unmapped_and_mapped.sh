#!/bin/bash

set -euo pipefail

########################################
# Usage
########################################

if [ "$#" -lt 3 ]; then
    echo "Usage:"
    echo "./04_kraken2.sh <run1|run2> <barcodeXX|all> <db1> [db2] [db3] ..."
    echo ""
    echo "Beispiele:"
    echo "./04_kraken2.sh run1 barcode13 bee_db"
    echo "./04_kraken2.sh run2 barcode05 beecornis_db lignaria_db"
    echo "./04_kraken2.sh run1 all kraken2-standard-db"
    exit 1
fi

########################################
# Parameters
########################################

RUN=$1
BARCODE=$2
shift 2

DB_NAMES=("$@")

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
# Kraken2 Database
########################################

DB_BASE="/drives/HDD_22TB_DATA/HDD03_06T_SDE/jspies"

SELECTED_DBS=()

for DB in "${DB_NAMES[@]}"
do
    DB_PATH="${DB_BASE}/${DB}"

    if [[ ! -d "${DB_PATH}" ]]; then
        echo "Database not found:"
        echo "${DB_PATH}"
        exit 1
    fi

    SELECTED_DBS+=("${DB_PATH}")
done

KRAKEN_DB=$(IFS=, ; echo "${SELECTED_DBS[*]}")

########################################
# Output
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
        echo "MISSING: ${FASTQ}"
        return 1
    fi

    echo ""
    echo "======================================="
    echo "START ${SAMPLE} (${TYPE})"
    echo "======================================="

########################################
# Kraken2
########################################

    echo "===== KRAKEN2 (${TYPE}) ====="

if [[ ${#SELECTED_DBS[@]} -eq 1 ]]
then

    conda run -n kraken2_env kraken2 \
        --db "${SELECTED_DBS[0]}" \
        --threads ${THREADS} \
        --report "${REPORT}" \
        --report-minimizer-data \
        --gzip-compressed \
        "${FASTQ}" \
        > "${RESULT}"

else

    conda run -n kraken2_env k2 classify \
        --db "${KRAKEN_DB}" \
        --threads ${THREADS} \
        --report "${REPORT}" \
        "${FASTQ}" \
        > "${RESULT}"

fi

########################################
# Controll
########################################

    if [[ ! -s "${RESULT}" ]]; then
        echo "ERROR: Kraken2-Output was not created."
        return 1
    fi

########################################
# Statistics
########################################

    CLASSIFIED=$(grep "^C" "${RESULT}" | wc -l)
    UNCLASSIFIED=$(grep "^U" "${RESULT}" | wc -l)

    echo -e "${SAMPLE}\t${TYPE}\tclassified:${CLASSIFIED}\tunclassified:${UNCLASSIFIED}" \
        | tee -a "${LOG_DIR}/kraken_summary.txt"

    echo ""
    echo "===== ${SAMPLE} (${TYPE}) Done ====="

}

########################################
# Choose Barcode
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
# Done
########################################

echo ""
echo "========================================="
echo "PIPELINE DONE"
echo "========================================="