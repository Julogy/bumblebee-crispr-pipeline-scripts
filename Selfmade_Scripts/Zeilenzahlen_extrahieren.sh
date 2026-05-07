root="/home/jupyter-jspies/Ergebnisse"
outfile="crispr_counts_table.tsv"

tmp=$(mktemp)

find "$root" -type f \( -name "*.txt" -o -name "*.csv" \) \
! -path "*/Vergleich_gefilterter_Repeats/*" |
while read -r file; do

    if [[ $file =~ Ergebnisse/([^/]+)/CRISPRclassify/([^/]+)/ ]]; then
        sample="${BASH_REMATCH[1]}"
        y="${BASH_REMATCH[2]}"
    else
        continue
    fi

    case "$y" in
        Crass) base="crass"; blast=0 ;;
        MCAAT) base="mcaat"; blast=0 ;;
        Crass_blasted) base="crass"; blast=1 ;;
        MCAAT_blasted) base="mcaat"; blast=1 ;;
        *) continue ;;
    esac


    fname=$(basename "$file")


    # ---------- NONE / BLAST (.txt) ----------
    if [[ "$fname" == *.txt ]]; then

        lines=$(wc -l < "$file")

        if [[ $blast -eq 1 ]]; then
            filter="blast"
        else
            filter="none"
        fi

        echo -e "$sample\t$base\t$filter\t$lines" >> "$tmp"
    fi


    # ---------- PROB (.csv) ----------
    if [[ $fname =~ Prob_([0-9.]+) ]]; then

        prob="${BASH_REMATCH[1]}"

        lines=$(wc -l < "$file")
        lines=$((lines-1))

        filter="prob $prob"
        [[ $blast -eq 1 ]] && filter="$filter blast"

        echo -e "$sample\t$base\t$filter\t$lines" >> "$tmp"
    fi


    # ---------- DIST (.csv) ----------
    if [[ $fname =~ Dist_([0-9]+) ]]; then

        dist="${BASH_REMATCH[1]}"

        lines=$(wc -l < "$file")
        lines=$((lines-1))

        filter="dist $dist"
        [[ $blast -eq 1 ]] && filter="$filter blast"

        echo -e "$sample\t$base\t$filter\t$lines" >> "$tmp"
    fi

done



awk -F'\t' -v OFS="\t" '

{
samples[$1]

if($2=="crass"){
    crass[$3]
}
else if($2=="mcaat"){
    mcaat[$3]
}

data[$1,$2,$3]=$4
}

END{

printf "sample"

for(c in crass) printf OFS "crass"
for(c in mcaat) printf OFS "mcaat"
print ""

printf " "

for(c in crass) printf OFS c
for(c in mcaat) printf OFS c
print ""

for(s in samples){

printf s

for(c in crass){
v=data[s,"crass",c]
if(v=="") v=0
printf OFS v
}

for(c in mcaat){
v=data[s,"mcaat",c]
if(v=="") v=0
printf OFS v
}

print ""
}

}
' "$tmp" > tmp_table.tsv



{
head -n2 tmp_table.tsv
(
tail -n +3 tmp_table.tsv | grep -v '^[0-9]'
tail -n +3 tmp_table.tsv | grep '^[0-9]' | sort -n
)
} > "$outfile"


rm "$tmp" tmp_table.tsv

echo "Tabelle geschrieben nach $outfile"