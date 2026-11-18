"""Paquet d'appgen (T-214) : apps/<nom>/app.yaml -> manifests OpenChoreo v1.3.3 ou Application Argo CD.

Role : regrouper les modules d'appgen par responsabilite, a comportement constant par rapport a l'ancien
appgen.py monolithique. Point d'entree inchange : `python3 tools/appgen/appgen.py <commande>`.
Entrees : apps/*/app.yaml, clusters/*/capabilities.yaml, platform/, pins/, generated/ (releases conservees).
Sorties : arbre generated/ (render), diagnostics (validate, check), pins/*.yaml (pin-resource, pin-project).

Modules, du plus bas au plus haut :
- config : chemins et constantes de politique ;
- model : chargement YAML, politique de cluster, contexte, normalisation de app.yaml ;
- schema : schema JSON, garde-fous env/secrets et values.yaml ;
- egress : regles E3 (validation, parametres du ClusterProjectType, apercus NetworkPolicy/CNP) ;
- semantic : regles semantiques d'une app native ou helm ; validate : validation de tout le depot ;
- platform_index : index de platform/ (CCT, ClusterTrait, CPT, Environment) ; gateway : controle G1 ;
- catalog, render_component, render_native, render_helm, render : rendu ;
- gitops : controles de check (derive, releases supprimees, pins) ; cli : commandes.
"""
