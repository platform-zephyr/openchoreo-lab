#!/usr/bin/env bash
# open-oke-access.sh : acces operateur temporaire a l'API PRIVEE du cluster OKE oracle-a1 (PLT-384).
# Cree UNE session du bastion `homelab-bastion` (port forwarding, TTL court), un tunnel SSH local et un
# kubeconfig temporaire (0600) dedie. Aucun secret en clair dans ce script : il utilise l'identite OCI
# de l'operateur (~/.oci/config). Ne cree ni identite IAM, ni cle NetBird. Ferme tout avec `close`.
# Usage : open-oke-access.sh open [TTL_SECONDES<=10800]  |  open-oke-access.sh close
set -euo pipefail
export PATH=/opt/homebrew/bin:$PATH
unset NODE_TLS_REJECT_UNAUTHORIZED
STATE="${OKE_ACCESS_DIR:-$HOME/.cache/oke-access}"; LPORT="${OKE_LOCAL_PORT:-16443}"
KCFG="$STATE/kubeconfig"
mkdir -p "$STATE"; chmod 700 "$STATE"
T="$(awk -F= '/^tenancy/{print $2}' ~/.oci/config)"
case "${1:-}" in
open)
  TTL="${2:-7200}"
  CID="$(oci ce cluster list -c "$T" --lifecycle-state ACTIVE --name oracle-a1 --query 'data[0].id' --raw-output)"
  EP="$(oci ce cluster get --cluster-id "$CID" --query 'data.endpoints."private-endpoint"' --raw-output)"
  IP="${EP%:*}"; PORT="${EP#*:}"
  BAS="$(oci bastion bastion list -c "$T" --all --name homelab-bastion --query 'data[0].id' --raw-output)"
  [ -f "$STATE/key" ] || ssh-keygen -q -t ed25519 -N '' -f "$STATE/key"
  SID="$(oci bastion session create-port-forwarding --bastion-id "$BAS" --display-name "oke-access-$(date +%s)" \
    --ssh-public-key-file "$STATE/key.pub" --key-type PUB --target-private-ip "$IP" --target-port "$PORT" \
    --session-ttl "$TTL" --wait-for-state SUCCEEDED --wait-for-state FAILED --query 'data.resources[0].identifier' --raw-output)"
  echo "$SID" > "$STATE/session.id"
  CMD="$(oci bastion session get --session-id "$SID" --query 'data."ssh-metadata".command' --raw-output)"
  CMD="${CMD//<privateKey>/$STATE/key}"; CMD="${CMD//<localPort>/$LPORT}"
  # tunnel en arriere-plan
  nohup bash -c "exec ${CMD} -N -o StrictHostKeyChecking=accept-new -o ExitOnForwardFailure=yes -o ServerAliveInterval=30" >"$STATE/tunnel.log" 2>&1 &
  echo $! > "$STATE/tunnel.pid"; sleep 4
  # kubeconfig temporaire : l'API est atteinte via 127.0.0.1:$LPORT ; le SAN du certificat peut ne pas couvrir 127.0.0.1,
  # on fixe donc le nom de serveur TLS sur l'IP privee (le TLS reste verifie, jamais desactive).
  umask 077
  oci ce cluster create-kubeconfig --cluster-id "$CID" --file "$KCFG" --kube-endpoint PRIVATE_ENDPOINT \
    --token-version 2.0.0 --overwrite >/dev/null
  chmod 600 "$KCFG"
  KUBECONFIG="$KCFG" kubectl config set-cluster "$(KUBECONFIG="$KCFG" kubectl config view -o jsonpath='{.clusters[0].name}')" \
    --server "https://127.0.0.1:$LPORT" --tls-server-name "$IP" >/dev/null
  echo "OK. export KUBECONFIG=$KCFG ; verifier : kubectl config current-context (jamais admin@homeops) ; fermer : $0 close"
  ;;
close)
  [ -f "$STATE/tunnel.pid" ] && kill "$(cat "$STATE/tunnel.pid")" 2>/dev/null || true
  [ -f "$STATE/session.id" ] && oci bastion session delete --session-id "$(cat "$STATE/session.id")" --force 2>/dev/null || true
  rm -f "$KCFG" "$STATE/session.id" "$STATE/tunnel.pid" "$STATE/key" "$STATE/key.pub"
  echo "ferme : session bastion supprimee, tunnel arrete, kubeconfig et cle ephemere effaces"
  ;;
*) echo "usage: $0 open [ttl] | close" >&2; exit 2;;
esac
