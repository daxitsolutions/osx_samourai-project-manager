# Consignes de validation et de documentation

## Tests et comptes rendus

- Conserver les sources de tests et leur documentation dans `tests/` (nom en minuscules).
- Pour chaque correction ou changement de comportement, exécuter les tests pertinents et créer ou mettre à jour un compte rendu dans `tests/reports/`.
- Nommer le compte rendu `AAAA-MM-JJ-issue-N.md`, ou `AAAA-MM-JJ-sujet.md` en l'absence d'issue. Lors d'une nouvelle exécution, ajouter une section datée sans effacer les résultats précédents.
- Indiquer la date, l'issue/PR, le commit réellement testé, l'environnement, les commandes exactes, les scénarios, leurs résultats et les limites de validation. Si les sources testées ne sont pas commitées, préciser le commit de base et les modifications concernées.
- Distinguer explicitement : **réussi**, **échoué**, **bloqué**, **non exécuté**, **en attente** et **en cours**. Un test n'est réussi que si son exécution est constatée ; une checklist cochée ou une commande proposée ne suffit pas.
- Joindre une sortie pertinente ou un lien vers le job CI. Ne jamais versionner de données utilisateur, secrets, chemins personnels inutiles ou journaux sensibles.
- Documenter toute adaptation du banc de test. Un test métier isolé ne valide pas la compilation de l'application complète ni son interface.
- Vérifier les checks de la PR et renseigner leurs résultats dans le compte rendu. Un job en attente reste en attente jusqu'à vérification de sa conclusion ; un résultat CI se rapporte uniquement au commit exécuté.
- Mettre à jour l'index de `tests/README.md` et ajouter un lien vers le compte rendu dans la PR.
- Garder les données de test et les écritures de persistance dans des dossiers temporaires indépendants des données réelles de l'utilisateur.

Les commandes de référence et le modèle de compte rendu figurent dans [tests/README.md](tests/README.md). Les checks automatisés sont définis dans [.github/workflows/checks.yml](.github/workflows/checks.yml).
