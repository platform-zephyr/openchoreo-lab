#!/usr/bin/env bash
# =============================================================================================
# DANGER — N'EXÉCUTER QUE SUR UN CLUSTER JETABLE. Remplit volontairement des PVC.
# =============================================================================================
# T-01 : trois PVC de tailles différentes (256Mi, 512Mi, 1Gi) ; on écrit taille + 128 Mio dans
#        chacun. PASS si l'écriture échoue (ENOSPC / quota) avant taille + 64 Mio ET si df voit
#        une capacité ≈ taille. Pour local-path (aucune limite annoncée) : FAIL attendu, noté.
# T-02 : on remplit A jusqu'au refus ; B et C restent inscriptibles et leur fichier témoin garde
#        son sha256. PASS si aucun autre PVC n'est touché.
source "$(dirname "$0")/lib.sh"
guard
ns="$(new_ns t01)"; trap 'drop_ns "$ns"' EXIT

declare -a NAMES=(a b c) SIZES=(256 512 1024)
for i in 0 1 2; do make_pvc "$ns" "${NAMES[$i]}" "${SIZES[$i]}Mi"; done
make_pod "$ns" w a b c

# Témoins de 16 Mio dans b et c.
for p in b c; do write_mib "$ns" w "/data/$p/witness" 16 >/dev/null; done
SHA_B="$(sha_of "$ns" w /data/b/witness)"; SHA_C="$(sha_of "$ns" w /data/c/witness)"

for i in 0 1 2; do
  p="${NAMES[$i]}"; s="${SIZES[$i]}"
  df_kib="$(pexec "$ns" w "df -k /data/$p | tail -1 | awk '{print \$2}'")"
  write_mib "$ns" w "/data/$p/fill" $((s + 128)) > /tmp/st-dd-$$ 2>&1 && rc=0 || rc=$?
  written_mib="$(pexec "$ns" w "du -m /data/$p/fill | cut -f1")"
  { echo "pvc=$p demande=${s}Mi df_total_kib=$df_kib dd_rc=$rc ecrit_mib=$written_mib"; cat /tmp/st-dd-$$; } | evidence T-01
  rm -f /tmp/st-dd-$$
  df_mib=$((df_kib / 1024))
  if [[ $rc -ne 0 && $written_mib -le $((s + 64)) && $df_mib -le $((s * 12 / 10 + 64)) ]]; then
    record T-01 PASS "$p : taille appliquée (df ${df_mib} Mio, écrit ${written_mib} Mio pour ${s} Mio)"
  else
    note=""; size_enforcement_claimed || note=" — attendu pour local-path (pas de limite)"
    record T-01 FAIL "$p : taille NON appliquée (df ${df_mib} Mio, écrit ${written_mib} Mio pour ${s} Mio)$note"
  fi
  # On garde le fichier de a plein pour T-02 ; on libère b et c.
  [[ $p != a ]] && pexec "$ns" w "rm -f /data/$p/fill"
done

# T-02 : a est plein (ou a débordé). b et c doivent rester sains et inscriptibles.
ok=yes
[[ "$(sha_of "$ns" w /data/b/witness)" == "$SHA_B" ]] || ok=no
[[ "$(sha_of "$ns" w /data/c/witness)" == "$SHA_C" ]] || ok=no
write_mib "$ns" w /data/b/after 8 >/dev/null || ok=no
write_mib "$ns" w /data/c/after 8 >/dev/null || ok=no
pexec "$ns" w "df -k /data/a /data/b /data/c" | evidence T-02
if [[ $ok == yes ]]; then record T-02 PASS "a plein ; b et c intacts (sha256) et inscriptibles"
else record T-02 FAIL "le remplissage de a a affecté b ou c (FS partagé ?)"; fi
finish
