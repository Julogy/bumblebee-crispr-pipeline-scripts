set -euo pipefail

input="$1"

awk '/^>DR/ {print; getline; print}
' /home/jupyter-jspies/Ergebnisse/$input/repeats_und_spacer/mcaat_R1_und_R2.fasta > /home/jupyter-jspies/Ergebnisse/$input/CRISPRclassify/MCAAT/repeats_R1_und_R2.fasta
awk '/^>DR/ {print; getline; print}
' /home/jupyter-jspies/Ergebnisse/$input/repeats_und_spacer/mcaat_R1_und_R2.fasta > /home/jupyter-jspies/Ergebnisse/$input/BLAST/MCAAT/repeats_R1_und_R2.fasta
awk '/^>SP/ {print; getline; print}
' /home/jupyter-jspies/Ergebnisse/$input/repeats_und_spacer/mcaat_R1_und_R2.fasta > /home/jupyter-jspies/Ergebnisse/$input/BLAST/MCAAT/spacer_R1_und_R2.fasta
awk 'NR%2==0 {print $1}
' /home/jupyter-jspies/Ergebnisse/$input/CRISPRclassify/MCAAT/repeats_R1_und_R2.fasta > /home/jupyter-jspies/Ergebnisse/$input/CRISPRclassify/MCAAT/repeats_mcaat.txt