set -euo pipefail

input="$1"

#repeats_und_spacer in repeats und spacer aufteilen
awk '/^>DR/ {print; getline; print}
' /home/jupyter-jspies/Ergebnisse/$input/repeats_und_spacer/crass_R1_und_R2.fasta > /home/jupyter-jspies/Ergebnisse/$input/CRISPRclassify/Crass/repeats_R1_und_R2.fasta
awk '/^>DR/ {print; getline; print}
' /home/jupyter-jspies/Ergebnisse/$input/repeats_und_spacer/crass_R1_und_R2.fasta > /home/jupyter-jspies/Ergebnisse/$input/BLAST/Crass/repeats_R1_und_R2.fasta
awk '/^>SP/ {print; getline; print}
' /home/jupyter-jspies/Ergebnisse/$input/repeats_und_spacer/crass_R1_und_R2.fasta > /home/jupyter-jspies/Ergebnisse/$input/BLAST/Crass/spacer_R1_und_R2.fasta
awk 'NR%2==0 {print $1}
' /home/jupyter-jspies/Ergebnisse/$input/CRISPRclassify/Crass/repeats_R1_und_R2.fasta > /home/jupyter-jspies/Ergebnisse/$input/CRISPRclassify/Crass/repeats_crass.txt