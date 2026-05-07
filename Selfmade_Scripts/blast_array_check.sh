set -euo pipefail

input="$1"


makeblastdb -in $input/all_arrays.fasta -dbtype nucl -out $input/DB/all_arrays_DB

blastn -db $input/DB/all_arrays_DB -query $input/query/found_arrays_meta.fasta \
       -task blastn-short -outfmt "6 qseqid sseqid pident length qlen evalue bitscore" -evalue 1000000 -word_size 10 -dust no -soft_masking false \
       > $input/arrays_found.tab

awk '{ 
    pident=$3; len=$4; qlen=$5; 
    if (len >= 69) {
        print 
    }
}' $input/arrays_found.tab > $input/arrays_found_filtered_set_length_69.tab
