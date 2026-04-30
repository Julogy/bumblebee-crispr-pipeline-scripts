set -euo pipefail

input="$1"


source $(conda info --base)/etc/profile.d/conda.sh
#Eigentliches Programm
cd /home/jupyter-jspies/GitHub/CRISPRDetect_2.2/
conda deactivate && conda run -n CrisprDetect_env perl CRISPRDetect.pl -f $input/arrays/mcaat_R1_und_R2.fasta -o $input/CRISPRDetect/MCAAT/CRISPRDetect -check_direction 0 -array_quality_score_cutoff 3 -T 5 -minimum_repeat_length 23 -minimum_no_of_repeats 3 > /dev/null
cd /home/jupyter-jspies/


#Filter
CRISPR_OUTPUT="$input/CRISPRDetect/MCAAT/CRISPRDetect"
grep -oP 'Group\|\d+' "$CRISPR_OUTPUT" | sed 's/[[:space:]]*$//; s/|$//; s/|/\\|/g; s/.*/&(\\||$)/' > $input/Detected_Groups.txt


#Filter zu .fasta machen
conda run -n seqkit_env seqkit grep -w 0 -r -f $input/Detected_Groups.txt $input/repeats_und_spacer/mcaat_R1_und_R2.fasta > $input/CRISPRDetect/MCAAT/CRISPR_detected_sequences.fasta


#Vorbereitung für CRISPRclassify
awk '/^>DR/ {print; getline; print}
' $input/CRISPRDetect/MCAAT/CRISPR_detected_sequences.fasta > $input/CRISPRclassify/MCAAT_detected/repeats_R1_und_R2.fasta

awk 'NR%2==0 {print $1}
' $input/CRISPRclassify/MCAAT_detected/repeats_R1_und_R2.fasta > $input/CRISPRclassify/MCAAT_detected/repeats_mcaat_detected.txt

