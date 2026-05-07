set -euo pipefail
BASE="$1"
# repeats und spacer rausholen 
awk '
function out(){
    if(!gid) return
    print drh
    print dr

    use_order=0
    if(length(fs_next) > 0){
        start=""
        for(sid in cspacers){
            if(!(sid in bs_prev)){
                start=sid
                break
            }
        }
        delete visited
        cur=start
        cnt=0
        while(cur != "" && !(cur in visited)){
            visited[cur]=1
            cnt++
            cur=fs_next[cur]
        }
        if(cur=="") use_order=1
    }

    if(use_order){
        delete visited
        cur=start
        while(cur != "" && !(cur in visited)){
            visited[cur]=1
            if(cur in sp_seq){
                print sp_head[cur]
                print sp_seq[cur]
            }
            cur=fs_next[cur]
        }
        # Fehlende Spacer (nicht im Assembly) anhängen
        for(i=1; i<=n; i++){
            sid_xml=sph[i]
            # Spacer-ID aus Header extrahieren
            split(sid_xml, tmp, "|")
            sid="SP"tmp[4]
            if(!(sid in visited)){
                print sph[i]
                print sp[i]
            }
        }
    } else {
        for(i=1; i<=n; i++){
            print sph[i]
            print sp[i]
        }
    }

    delete sp_seq; delete sp_head
    delete cspacers; delete bs_prev; delete fs_next; delete visited
    n=0; in_assembly=0; cur_cspacer=""
}

/<group .*drseq=/{
    out()
    match($0,/gid="G([0-9]+)"/,g)
    match($0,/drseq="([ACGT]+)"/,d)
    gid=g[1]; dr=d[1]
    drh=">DR|Group|" gid "|"
}

/<spacer /{
    if(!in_assembly){
        match($0,/spid="SP([0-9]+)"/,s)
        match($0,/seq="([ACGT]+)"/,q)
        sid="SP"s[1]
        sp_head[sid]=">SP|Group|" gid "|" s[1] "|"
        sp_seq[sid]=q[1]
        sph[++n]=sp_head[sid]
        sp[n]=q[1]
    }
}

/<assembly>/{ in_assembly=1 }
/<\/assembly>/{ in_assembly=0 }

in_assembly && /^[[:space:]]*<cspacer spid=/{
    match($0,/spid="SP([0-9]+)"/,s)
    cur_cspacer="SP"s[1]
    cspacers[cur_cspacer]=1
}

in_assembly && /^[[:space:]]*<bs /{
    match($0,/spid="SP([0-9]+)"/,s)
    bs_prev[cur_cspacer]="SP"s[1]
}

in_assembly && /^[[:space:]]*<fs /{
    match($0,/spid="SP([0-9]+)"/,s)
    fs_next[cur_cspacer]="SP"s[1]
}

END{ out() }
' "$BASE/Crass/crass.crispr" > "$BASE/repeats_und_spacer/crass_R1_und_R2.fasta"

#repeats und spacer in arrays umbauen bei crass
awk '
/^>/{
    split(substr($0,2),a,"|")
    t=a[1]; g=a[3]
    if(t=="SP") i[g]++
    next
}

t=="DR"{ dr[g]=$0 }
t=="SP"{ sp[g,i[g]]=$0 }

END{
    for(g in dr){
        printf(">array|Group|%s|\n%s",g,dr[g])
        for(j=1;j<=i[g];j++) printf("%s%s",sp[g,j],dr[g])
        print ""
    }
}' "$BASE/repeats_und_spacer/crass_R1_und_R2.fasta" > "$BASE/arrays/crass_R1_und_R2.fasta"

# im Ordner /home/jupyter-jspies/Ergebnisse/.../Crass/ zum aufräumen alles außer der .crispr löschen (weil nur die benutze ich)
cd "$BASE/Crass/"
find . -type f ! -name "*.crispr" -delete
cd /home/jupyter-jspies/