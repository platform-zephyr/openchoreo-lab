# vikunja : NON PORTE (pas de app.yaml)

Source kube-ops : `k8s/applications/catalog/vikunja/` @ origin/main [C]. Date : 2026-11-17.

Image verifiee : index `sha256:e2204a1c1c6a81e833c2b3a5442be182ca2335b54c2e7e37578cc3fe12a27cfc` contient linux/arm64 (`bc3ba3be...`) [C]. kube-ops pinne le tag seul `2.7.0`.

Raisons precises (deux bloquants, le premier suffit a refuser le descripteur) :

1. **Connexion PostgreSQL** : le schema injecte une seule variable URL (`database.envVar`, defaut `DATABASE_URL`, cf. `tools/appgen/appgen.py` ligne 849). kube-ops [C] configure Vikunja par variables discretes `VIKUNJA_DATABASE_HOST`, `_DATABASE`, `_USER`, `_PASSWORD` lues dans les cles du secret CNPG (`host`, `dbname`, `user`, `password`), plus `VIKUNJA_DATABASE_SSLMODE`. Une URL seule ne suffit pas. **Extension requise** : mapping de cles de secret vers variables (ex. `database.vars: {VIKUNJA_DATABASE_HOST: host, ...}`), ou format `discrete`.
2. **Sauvegarde** : les donnees Vikunja (taches) ne sont pas regenerables. `backup.class: irreplaceable` est refuse par la CI (D-2026-11-14-03). `regenerable` serait faux. `none` accepte la perte. Les capabilities n'admettent que `backupMechanisms: [none]`, donc le `ScheduledBackup` CNPG vers R2 de kube-ops n'a pas d'equivalent. **Extension requise** : admettre `cnpg` dans les capabilities (PR plateforme) + instance `lab-pg` sauvegardee (`backup: cnpg` au lieu de `none`), decision de Paul.

Non bloquants (a traiter au portage) : OIDC ThunderID (variables `VIKUNJA_AUTH_OPENID_PROVIDERS_*`, prefixe secret `VIKUNJA_`) ; `runAsUser 1000` admis ; stockage `block-rwo` 2Gi pour `/app/vikunja/files`.

Decision : aucun app.yaml tant que les extensions 1 et 2 ne sont pas acceptees. Ne pas ecrire de `backup.class` mensonger.
