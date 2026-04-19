set -euo pipefail

input="$1"


#BLAST

cd /home/jupyter-jspies/Ergebnisse/$input/BLAST/MCAAT


mkdir temp_spacer temp_repeats temp_db
awk '
/^>/ {
    split($0,a,"|")
    group=a[3]
    file="temp_spacer/group|"group".fasta"
    close(file)
}
{ print >> file }
' spacer_R1_und_R2.fasta

awk '
/^>/ {
    split($0,a,"|")
    group=a[3]
    file="temp_repeats/group|"group".fasta"
    close(file)
}
{ print >> file }
' repeats_R1_und_R2.fasta
rm -f spacer_repeat_match_same_Group.tab
rm -f temp_db/makeblastdb.log 

time for f in temp_spacer/group\|*.fasta
do
    group=$(basename "$f" .fasta | cut -d"|" -f2)

    if [ -f "temp_repeats/group|${group}.fasta" ]; then
        
        makeblastdb -in "temp_repeats/group|${group}.fasta" \
                    -dbtype nucl \
                    -out "temp_db/db|${group}" \
                    >> temp_db/makeblastdb.log 

        blastn \
        -db "temp_db/db|${group}" \
        -query "$f" \
        -task blastn-short \
        -outfmt "6 qseqid sseqid pident length qlen slen evalue bitscore" \
        -evalue 1000000 \
        -word_size 4 \
        -dust no \
        -soft_masking false \
        >> spacer_repeat_match_same_Group.tab
    fi
done
awk '{ 
    pident=$3; len=$4; qlen=$5; slen=$6;
    # Check: Identität >= 80% UND Länge des Alignments mindestens 80 % des spacers (kein 4 basen alignment bei sequenzen die 20 basen haben)
    if (pident >= 80 && (len >= (qlen * 0.80) || len >= (slen * 0.80))) {
        print $1
    }
}' spacer_repeat_match_same_Group.tab > blacklisted_spacers.txt
awk '{
        if (match($1, /Group\|([0-9]+)/, arr)) {
            print "Group\\|" arr[1] "(\\||$)"
        }
    }
' blacklisted_spacers.txt | sort -u > /home/jupyter-jspies/Groups.txt





#seqkit lauf zum filtern

conda run -n seqkit_env seqkit grep -w 0 -v -r -f /home/jupyter-jspies/Groups.txt /home/jupyter-jspies/Ergebnisse/$input/repeats_und_spacer/mcaat_R1_und_R2.fasta > /home/jupyter-jspies/Ergebnisse/$input/BLAST/MCAAT/CRISPR_Blast_filtered_sequences.fasta





#aufteilen der Dateien

awk '/^>DR/ {print; getline; print}
' /home/jupyter-jspies/Ergebnisse/$input/BLAST/MCAAT/CRISPR_Blast_filtered_sequences.fasta > /home/jupyter-jspies/Ergebnisse/$input/CRISPRclassify/MCAAT_blasted/repeats_R1_und_R2.fasta

awk 'NR%2==0 {print $1}
' /home/jupyter-jspies/Ergebnisse/$input/CRISPRclassify/MCAAT_blasted/repeats_R1_und_R2.fasta > /home/jupyter-jspies/Ergebnisse/$input/CRISPRclassify/MCAAT_blasted/repeats_mcaat_blasted.txt

rm -rf temp_spacer temp_repeats temp_db