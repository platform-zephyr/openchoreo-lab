# CLEANUP — supprimer l'essai sans toucher au reste d'OKE

> Statut : **procédure à tester** (sera rejouée sur k3d en Phase A puis sur OKE en Phase D). Ne rien exécuter hors des namespaces listés.

Ordre :
1. Dans Argo CD : supprimer l'Application racine du labo (`openchoreo-lab`) et l'AppProject du labo. Avec `Prune=false`, les objets restent : étape suivante.
2. Supprimer les Components (les finalizers nettoient le data plane) : `kubectl delete component -A --all -l app.kubernetes.io/part-of=openchoreo-lab`.
3. Supprimer les namespaces d'essai : `lab-*`, `dp-*` créés par OpenChoreo, puis `openchoreo-control-plane`, `openchoreo-data-plane`.
4. Désinstaller les charts Helm de l'essai (`helm -n <ns> uninstall`), dans l'ordre inverse de l'installation.
5. Supprimer les CRD `*.openchoreo.dev` **uniquement** si aucune autre installation n'existe sur le cluster ; puis les ClusterRole/ClusterRoleBinding/webhooks `openchoreo-*` restants.
6. Vérifier : `kubectl get ns | grep -E 'lab-|openchoreo|dp-'` vide ; `kubectl get crd | grep openchoreo` vide ; aucun PVC orphelin ; les 3 volumes de 50 Go d'origine d'OKE intacts.
7. Archiver ou supprimer le dépôt : `gh repo archive platform-zephyr/openchoreo-lab` (réversible) ou `gh repo delete` (geste de Paul).

Interdits : toucher aux namespaces d'OKE hors labo, supprimer des volumes OCI, `tofu apply/destroy`.
