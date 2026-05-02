set -euo pipefail
BASE="$1"
# repeats und spacer rausholen und arrays mit zu vielen kurzen spacern raushauen
awk '
function print_group(){
    if (gid == "") return

    print dr_header
    print dr_seq

    for(i=1;i<=spacer_count;i++){
        print sp_header[i]
        print sp_seq[i]
    }
}
BEGIN{
    gid=""
}

/<group .*drseq=/{
    print_group()

    match($0,/drseq="([ACGT]+)"/,dr)
    match($0,/gid="G([0-9]+)"/,g)

    gid=g[1]
    dr_seq=dr[1]
    dr_header=">DR|Group|" gid "|"

    spacer_count=0
    short_spacers=0
    delete sp_header
    delete sp_seq
}

/<spacer /{
    match($0,/seq="([ACGT]+)"/,sp)
    match($0,/spid="SP([0-9]+)"/,sid)

    spacer_count++
    sp_seq[spacer_count]=sp[1]
    sp_header[spacer_count]=">SP|Group|" gid "|" sid[1] "|"

}

END{
    print_group()
}
' "$BASE/Crass/crass.crispr" > "$BASE/repeats_und_spacer/crass_R1_und_R2.fasta"

#repeats und spacer in arrays umbauen bei crass
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
' "$BASE/repeats_und_spacer/crass_R1_und_R2.fasta" > "$BASE/arrays/crass_R1_und_R2.fasta"

# im Ordner /home/jupyter-jspies/Ergebnisse/.../Crass/ zum aufräumen alles außer der .crispr löschen (weil nur die benutze ich)
cd "$BASE/Crass/"
find . -type f ! -name "*.crispr" -delete
cd /home/jupyter-jspies/