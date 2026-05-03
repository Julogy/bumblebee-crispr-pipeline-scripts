set -euo pipefail

input="$1"


source $(conda info --base)/etc/profile.d/conda.sh
#Eigentliches Programm
cd /home/jupyter-jspies/GitHub/CRISPRidentify/
conda run -n crispr_identify_env python CRISPRidentify.py --file $input/arrays/mcaat_R1_und_R2.fasta --result_folder $input/CRISPRidentify/MCAAT/ --min_len_rep 23 --max_len_rep 50 --min_repeats 3 --min_len_spacer 23 --max_len_spacer 50 > /dev/null
cd /home/jupyter-jspies/


#Filter
awk -F',' '
    $13=="Bona-fide" || $13=="Alternative" || $13=="Possible" {
        if (match($1, /Group-([0-9]+)/, arr)) {
            print "Group\\|" arr[1] "(\\||$)"
        }
    }
' $input/CRISPRidentify/MCAAT/Complete_summary.csv > $input/Identified_Groups.txt

find $input/CRISPRidentify/MCAAT/ -type f ! -name "Complete_summary.csv" -delete
find $input/CRISPRidentify/MCAAT/ -type d -empty -delete
rm -rf /home/jupyter-jspies/GitHub/CRISPRidentify/Identify_Temp*


#Filter zu .fasta machen
conda run -n seqkit_env seqkit grep -w 0 -r -f $input/Identified_Groups.txt $input/repeats_und_spacer/mcaat_R1_und_R2.fasta > $input/CRISPRidentify/MCAAT/CRISPR_identified_sequences.fasta


#Vorbereitung für CRISPRclassify
awk '/^>DR/ {print; getline; print}
' $input/CRISPRidentify/MCAAT/CRISPR_identified_sequences.fasta > $input/CRISPRclassify/MCAAT_identified/repeats_R1_und_R2.fasta

awk 'NR%2==0 {print $1}
' $input/CRISPRclassify/MCAAT_identified/repeats_R1_und_R2.fasta > $input/CRISPRclassify/MCAAT_identified/repeats_mcaat_identified.txt