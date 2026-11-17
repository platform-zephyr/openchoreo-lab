# Job CI `platform` : vérification de `platform/**` et `tools/oke/**` (revue I10, B2)

**Statut : texte prêt, NON intégré.** `.github/` est hors du périmètre de l'agent qui a écrit ce fichier : le coordinateur colle le job ci-dessous dans `.github/workflows/ci.yaml`, ajoute `platform` à `needs` du job `ci-ok`, puis vérifie la CI sur une PR. Rien ici ne lit de secret ni n'accède à un cluster.

## Pourquoi

Argo applique `platform/**` depuis `main` (`selfHeal`, étape 11). Aujourd'hui aucun job ne lint `platform/`, ne lance `shellcheck` sur `tools/oke`, ni ne contrôle les règles que l'AppProject ne peut pas exprimer (un AppProject ne restreint pas un **chemin** source). Une PR qui casse une VAP, ajoute un `ClusterAuthzRoleBinding` hors de `platform/authz/` ou une Application qui emprunte le projet `lab-authz` passerait `ci-ok`.

## Contrôles

| Contrôle | Commande | Échec si |
|---|---|---|
| YAML | `yamllint -c tools/appgen/yamllint.yaml platform tools/oke` | une erreur (les avertissements de longueur restent tolérés) |
| Scripts | `shellcheck -x -P SCRIPTDIR tools/oke/*.sh` puis `bash -n` | un constat |
| Règles Argo | `python3 -I tools/oke/argo_guard.py .` | Authz* synchronisé hors `platform/authz/` ; Application hors projet attendu ; objet cluster-scoped non nommé dans l'AppProject `lab` ; kind namespacé hors whitelist |
| Rendus Helm | `tools/oke/render-check.sh` (charts épinglés, sha256, cache Helm isolé) | `psa_check.py` en écart ; PVC, Service LB/NodePort ou image sans digest dans un rendu |
| Schémas | `kubeconform -strict` sur `platform/install/{manifests,argocd}`, `platform/policies` | objet invalide ou schéma manquant |

Le job `crd-schema` existant fournit déjà kubeconform vérifié par sha256 ; le job `platform` le réinstalle de la même manière. Les schémas des CRD tierces viennent des CRD des charts épinglés (`helm template --include-crds`) et de `tools/appgen/fetch-ext-schemas.sh` (Cilium, sha256 épinglé).

## Texte du job (à coller sous `jobs:` dans `.github/workflows/ci.yaml`)

```yaml
  platform:
    runs-on: ubuntu-24.04-arm
    env:
      HELM_VERSION: "v4.1.3"
      # Empreinte à relever par le coordinateur sur https://get.helm.sh/helm-v4.1.3-linux-arm64.tar.gz.sha256sum
      HELM_SHA256: "A_RELEVER"
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: actions/setup-python@6d4fd22b20465ccc0f7354476588e8df7c9ca0e0 # v7.1.0
        with:
          python-version: "3.12"
      - name: Outils (versions figées)
        run: |
          python3 -m pip install --disable-pip-version-check "yamllint==1.38.0" "PyYAML==6.0.2"
          sudo apt-get update -qq && sudo apt-get install -y -qq shellcheck
          curl -fsSLo /tmp/helm.tgz "https://get.helm.sh/helm-${HELM_VERSION}-linux-arm64.tar.gz"
          echo "${HELM_SHA256}  /tmp/helm.tgz" | sha256sum -c -
          tar -xzf /tmp/helm.tgz -C /tmp && sudo install /tmp/linux-arm64/helm /usr/local/bin/helm
          curl -fsSLo /tmp/kubeconform.tgz "https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}/kubeconform-linux-arm64.tar.gz"
          echo "${KUBECONFORM_SHA256}  /tmp/kubeconform.tgz" | sha256sum -c -
          tar -xzf /tmp/kubeconform.tgz -C /tmp && sudo install /tmp/kubeconform /usr/local/bin/kubeconform
          sudo snap install yq
      - name: yamllint platform et tools/oke
        run: yamllint -c tools/appgen/yamllint.yaml platform tools/oke
      - name: shellcheck et bash -n
        run: |
          shellcheck -x -P SCRIPTDIR tools/oke/*.sh
          for f in tools/oke/*.sh; do bash -n "$f"; done
      - name: Règles Argo (chemins, projets, whitelists nommées)
        run: python3 -I tools/oke/argo_guard.py .
      - name: Rendus Helm épinglés + PSA + 0 PVC/LB/image sans digest
        env:
          OKE_PHASEB_STATE: ${{ runner.temp }}/phaseb
        run: tools/oke/render-check.sh
      - name: kubeconform -strict (manifests plateforme)
        env:
          STATE: ${{ runner.temp }}/phaseb
        run: |
          mkdir -p "$STATE/crds" "$STATE/schemas"
          # Charts OpenChoreo exclus de la boucle (validate.yaml refuse les values par défaut) : leurs CRD
          # sont lues dans crds/ ci-dessous. Aucune erreur masquée.
          for t in "$STATE"/charts/*.tgz; do
            case "$t" in *openchoreo-*) continue;; esac
            helm template x "$t" --include-crds --set crds.enabled=true; echo '---'
          done > "$STATE/all.yaml"
          tar -xzf "$STATE"/charts/openchoreo-control-plane-*.tgz -C "$STATE"
          python3 -I - "$STATE/all.yaml" "$STATE/crds" <<'PY'
          import pathlib, sys, yaml
          out = pathlib.Path(sys.argv[2])
          for d in yaml.safe_load_all(open(sys.argv[1])):
              if isinstance(d, dict) and d.get("kind") == "CustomResourceDefinition":
                  (out / f"{d['metadata']['name']}.yaml").write_text(yaml.safe_dump(d))
          PY
          python3 tools/appgen/crd2schema.py "$STATE/crds" "$STATE/schemas"
          python3 tools/appgen/crd2schema.py "$STATE/openchoreo-control-plane/crds" "$STATE/schemas"
          tools/appgen/fetch-ext-schemas.sh "$STATE/ext" && cp -R "$STATE/ext/." "$STATE/schemas/"
          kubeconform -strict -summary -schema-location default \
            -schema-location "$STATE/schemas/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json" \
            platform/install/manifests/*.yaml platform/install/argocd/*.yaml \
            platform/install/argocd/apps/*.yaml platform/policies/*.yaml
```

Remarques pour l'intégration :
- `yq` (mikefarah) est requis par `render-check.sh` ; si `snap` n'est pas disponible sur le runner, l'installer depuis sa release GitHub avec une empreinte figée, comme kubeconform.
- `HELM_SHA256` doit être relevée avant le merge (aucune valeur inventée ici).
- Les CRD Gateway API (`standard-install.yaml` v1.5.1) ne sont pas dans les charts : `platform/install/manifests/*.yaml` n'en contient pas d'objets en dehors de `GatewayParameters` (kgateway) ; si un `Gateway` y est ajouté, télécharger le manifest au sha256 de `versions.env` et l'ajouter à `$STATE/all.yaml`.
- Ajouter `platform` à `needs` de `ci-ok`, et vérifier que la règle `main-protection` exige la revue des code owners (`tools/apply-branch-protection.sh`) : `platform/authz/` et `platform/install/argocd/` doivent rester sous `CODEOWNERS`.
