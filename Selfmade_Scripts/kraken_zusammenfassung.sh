#!/bin/bash

########################################
# Usage
########################################

if [ "$#" -ne 2 ]; then
    echo ""
    echo "Usage:"
    echo "./kraken_zusammenfassung.sh <run1|run2> <single|multi>"
    echo ""
    echo "Beispiele:"
    echo "./kraken_zusammenfassung.sh run1 single"
    echo "./kraken_zusammenfassung.sh run2 multi"
    exit 1
fi

########################################
# Parameters
########################################

RUN=$1
MODE=$2

if [[ "$MODE" != "single" && "$MODE" != "multi" ]]; then
    echo "Invalid Mode: $MODE"
    echo "Valid Modes: single or multi"
    exit 1
fi

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

OUTFILE_ALL="${REPORT_DIR}/kraken_summary.txt"
OUTFILE_MAPPED="${REPORT_DIR}/kraken_summary_mapped.txt"
OUTFILE_UNMAPPED="${REPORT_DIR}/kraken_summary_unmapped.txt"

> "$OUTFILE_ALL"
> "$OUTFILE_MAPPED"
> "$OUTFILE_UNMAPPED"

########################################
# Funktion
########################################

create_summary() {

    OUTFILE="$1"
    BARCODE="$2"
    shift 2

    FILES=("$@")

    echo "==================================================" >> "$OUTFILE"
    echo "$BARCODE" >> "$OUTFILE"
    echo "==================================================" >> "$OUTFILE"
    echo "" >> "$OUTFILE"

    #############################################
    # Total Reads
    #############################################

    if [[ "$MODE" == "single" ]]; then

        UNCLASS=$(awk '$7==0 {sum+=$2} END{print sum+0}' "${FILES[@]}")
        ROOT=$(awk '$7==1 {sum+=$2} END{print sum+0}' "${FILES[@]}")

    else

        UNCLASS=$(awk '$5==0 {sum+=$2} END{print sum+0}' "${FILES[@]}")
        ROOT=$(awk '$5==1 {sum+=$2} END{print sum+0}' "${FILES[@]}")

    fi

    TOTAL=$((UNCLASS + ROOT))
    CLASSIFIED=$ROOT

    if (( TOTAL > 0 )); then
        P_UNCLASS=$(awk -v a="$UNCLASS" -v b="$TOTAL" 'BEGIN{printf "%.2f",100*a/b}')
        P_CLASS=$(awk -v a="$CLASSIFIED" -v b="$TOTAL" 'BEGIN{printf "%.2f",100*a/b}')
    else
        P_UNCLASS="0.00"
        P_CLASS="0.00"
    fi

    echo "Total reads  : $TOTAL" >> "$OUTFILE"
    echo "Unclassified : $UNCLASS (${P_UNCLASS}%)" >> "$OUTFILE"
    echo "Classified   : $CLASSIFIED (${P_CLASS}%)" >> "$OUTFILE"
    echo "" >> "$OUTFILE"

    #############################################
    # Organisms
    #############################################

    echo "Organisms" >> "$OUTFILE"
    echo "--------------------------------------------------" >> "$OUTFILE"

    if [[ "$MODE" == "single" ]]; then

        awk '
        $6=="S"{
            name=$8
            for(i=9;i<=NF;i++)
                name=name" "$i
            count[name]+=$2
        }
        END{
            for(name in count)
                printf "%8d  %s\n",count[name],name
        }' "${FILES[@]}" | sort -nr >> "$OUTFILE"

    else

        awk '
        $4=="S"{
            name=$6
            for(i=7;i<=NF;i++)
                name=name" "$i
            count[name]+=$2
        }
        END{
            for(name in count)
                printf "%8d  %s\n",count[name],name
        }' "${FILES[@]}" | sort -nr >> "$OUTFILE"

    fi

    echo "" >> "$OUTFILE"
}

########################################
# Main  loop
########################################

for BARCODE in $(ls "$REPORT_DIR"/*_mapped.kreport | sed 's/_mapped.kreport//' | xargs -n1 basename | sort)
do

    MAPPED="${REPORT_DIR}/${BARCODE}_mapped.kreport"
    UNMAPPED="${REPORT_DIR}/${BARCODE}_unmapped.kreport"

    # mapped + unmapped
    create_summary "$OUTFILE_ALL" "$BARCODE" "$MAPPED" "$UNMAPPED"

    # nur mapped
    create_summary "$OUTFILE_MAPPED" "$BARCODE" "$MAPPED"

    # nur unmapped
    create_summary "$OUTFILE_UNMAPPED" "$BARCODE" "$UNMAPPED"

done

echo "DONE."
echo "Created:"
echo "  $OUTFILE_ALL"
echo "  $OUTFILE_MAPPED"
echo "  $OUTFILE_UNMAPPED"