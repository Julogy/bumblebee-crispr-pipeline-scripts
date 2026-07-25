#!/bin/bash

set -euo pipefail

########################################
# Usage
########################################

if [ "$#" -ne 3 ]; then
    echo ""
    echo "Usage:"
    echo "./02_mapping.sh <lauf1|lauf2> <genome.mmi> <barcodeXX|all>"
    echo ""
    echo "Beispiele:"
    echo "./02_mapping.sh lauf1 /drives/HDD_22TB_DATA/HDD03_06T_SDE/jspies/Tom_Pipeline_Wildbiene1/genome/Bombus.mmi barcode01"
    echo "./02_mapping.sh lauf2 /drives/HDD_22TB_DATA/HDD03_06T_SDE/jspies/Tom_Pipeline_Wildbiene1/genome/Bombus.mmi all"
    exit 1
fi

########################################
# Parameter
########################################

LAUF=$1
GENOME=$2
BARCODE=$3

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
LOG_DIR="${PROJECT_DIR}/logs"

########################################
# Referenz prüfen
########################################

if [[ ! -f "${GENOME}" ]]; then
    echo ""
    echo "FEHLER:"
    echo "Referenz nicht gefunden:"
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

    SORTED_BAM="${BAM_DIR}/${SAMPLE}_aligned_sorted.bam"

    FLAGSTAT="${LOG_DIR}/${SAMPLE}_flagstat.txt"

    if [[ ! -f "${FASTQ}" ]]; then
        echo "FEHLT: ${FASTQ}"
        return
    fi

    echo ""
    echo "======================================="
    echo "STARTE ${SAMPLE}"
    echo "======================================="

########################################
# Mapping und Sortieren
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

    # Falls am Ende eine leere Zeile existiert, entfernen
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
# BAM prüfen
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
# Zusammenfassung
########################################

    MAPPED=$(grep " mapped (" "${FLAGSTAT}" | head -1)

    > "${LOG_DIR}/mapping_summary.txt"

    echo -e "${SAMPLE}\t${MAPPED}" \
        | tee -a "${LOG_DIR}/mapping_summary.txt"

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

        run_mapping "${SAMPLE}"

    done

else

    run_mapping "${BARCODE}"

fi

########################################
# Fertig
########################################

echo ""
echo "========================================="
echo "PIPELINE FERTIG"
echo "========================================="