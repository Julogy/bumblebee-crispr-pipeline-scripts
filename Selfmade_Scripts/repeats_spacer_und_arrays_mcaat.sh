set -euo pipefail
BASE="$1"
#repeats und spacer aus der Ergebnis.txt bei mcaat rausholen und arrays mit zu vielen kurzen spacern raushauen
awk '

function print_group(){

    if (DRcount==0) return

    print dr_header
    print dr_seq

    for(i=1;i<=spacer_count;i++){
        print sp_header[i]
        print sp_seq[i]
    }
}

BEGIN {
    DRcount=0
    state="idle"
}

/^Number of Systems/ { exit }
/^Omitted Repeats/ { exit }

/^[-]+$/ {
    if(state=="idle") {
        state="expect_repeat"
    } 
    else if(state=="after_repeat") {
        state="in_spacers"
    } 
    else if(state=="in_spacers") {
        state="after_spacers"
    }
    next
}

/^Number of Spacers/ {
    state="idle"
    next
}

/^$/ { next }

{
    if(state=="expect_repeat") {

        print_group()

        DRcount++
        SPcount=0

        dr_seq=$0
        dr_header=">DR|Group|"DRcount"|"

        spacer_count=0
        short_spacers=0
        delete sp_header
        delete sp_seq

        state="after_repeat"
    }
    else if(state=="in_spacers") {
        SPcount++
        spacer_count++

        sp_seq[spacer_count]=$0
        sp_header[spacer_count]=">SP|Group|"DRcount"|"SPcount"|"

    }
}

END{
    print_group()
}

' "$BASE/MCAAT/CRISPR_Arrays.txt" > "$BASE/repeats_und_spacer/mcaat_R1_und_R2.fasta"

#repeats und spacer in arrays umbauen bei mcaat
awk '
/^>/ {
    header = substr($0,2)
    split(header, a, "|")
    type = a[1]
    group = a[3]

    if (type == "DR") {
        dr[group] = ""
        current_group = group
    } else if (type == "SP") {
        sp_index[group]++
        current_group = group
        current_sp = sp_index[group]
    }
    next
}

{
    if (type == "DR") {
        dr[current_group] = $0
    } else if (type == "SP") {
        spacer[current_group, current_sp] = $0
    }
}

END {
    for (g in dr) {
        printf(">array|Group|%s|\n", g)

        # Array korrekt zusammensetzen
        printf("%s", dr[g])
        for (i = 1; i <= sp_index[g]; i++) {
            printf("%s%s", spacer[g,i], dr[g])
        }
        printf("\n")   # <<< WICHTIGER Zeilenumbruch
    }
}
' "$BASE/repeats_und_spacer/mcaat_R1_und_R2.fasta" > "$BASE/arrays/mcaat_R1_und_R2.fasta"