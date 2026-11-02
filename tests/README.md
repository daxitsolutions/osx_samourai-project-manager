# Tests et historique de validation

Le dossier `tests/` contient les tests exécutables et les comptes rendus de validation. Les consignes applicables aux contributions et aux agents sont dans [AGENTS.md](../AGENTS.md).

## Commandes de référence

Depuis la racine du dépôt, avec une chaîne Xcode compatible avec Swift 6.2 ou plus récent :

```bash
swift test --parallel
swift build -c release --product SamouraiProjectManager
```

Pour le smoke test Merlin indépendant :

```bash
test_binary_dir="$(mktemp -d)"
swiftc -swift-version 6 \
  Sources/SamouraiProjectManagerApp/Support/MerlinProjectImportService.swift \
  tests/MerlinImportSmoke/main.swift \
  -o "$test_binary_dir/merlin-import-smoke"
"$test_binary_dir/merlin-import-smoke"
rm -r "$test_binary_dir"
```

L'échec d'une commande de compilation doit être traité avant d'exécuter le binaire. En CI, le shell arrête automatiquement l'étape au premier échec.

## Checks GitHub Actions

Le workflow [Checks](../.github/workflows/checks.yml) lance trois jobs distincts sur chaque pull request et sur les mises à jour de `main` :

| Check | Ce qu'il vérifie |
|---|---|
| Tests de non-régression | Suite Swift Testing, dont la protection du chargement contre les identifiants dupliqués et l'accès restreint à l'API REST locale. |
| Import Merlin | Import XML, hiérarchie, dépendances, namespace et rejet d'un format non pris en charge. |
| Compilation Release | Compilation complète du produit, sans lancement ni validation visuelle de l'interface. |

## Comptes rendus

| Date | Sujet | Compte rendu |
|---|---|---|
| 2026-11-02 | Issue #32 — identifiants dupliqués au chargement | [Résultats et limites](reports/2026-11-02-issue-32.md) |
| 2026-11-02 | Issue #34 — récupération après échec de chargement | [Résultats et limites](reports/2026-11-02-issue-34.md) |
| 2026-11-02 | Issue #36 — réimport des risques sans perte d’identité ni d’historique | [Résultats et limites](reports/2026-11-02-issue-36.md) |
| 2026-11-02 | Issue #37 — annulation d’import sans résultat partiel | [Résultats et limites](reports/2026-11-02-issue-37.md) |
| 2026-11-02 | Issue #38 — doublons internes d’un import de ressources | [Résultats et limites](reports/2026-11-02-issue-38.md) |
| 2026-11-02 | Issue #39 — API REST limitée à la boucle locale | [Résultats et limites](reports/2026-11-02-issue-39.md) |
| 2026-11-02 | Issue #42 — moteur métier commun des imports | [Résultats et limites](reports/2026-11-02-issue-42.md) |
| 2026-11-02 | Issue #41 — validation, normalisation et publication communes | [Résultats et limites](reports/2026-11-02-issue-41.md) |
| 2026-11-02 | Issue #55 — analyse Merlin hors du MainActor, XML et SQLite volumineux | [Résultats et limites](reports/2026-11-02-issue-55.md) |
| 2026-11-02 | Issue #75 — compilation avec Xcode quand les Command Line Tools sont actifs | [Résultats et limites](reports/2026-11-02-issue-75.md) |
| 2026-11-02 | Issue #49 — dashboard aligné sur le projet actif ou le portefeuille | [Résultats et limites](reports/2026-11-02-issue-49.md) |
| 2026-11-02 | Plantage du menu de statut dans Risques | [Résultats et limites](reports/2026-11-02-plantage-risques-statut.md) |

## Modèle à suivre

Créer `reports/AAAA-MM-JJ-issue-N.md` avec les rubriques suivantes :

1. **Périmètre** : issue, PR, commit testé et éventuelles modifications non commitées.
2. **Environnement** : système, Swift/Xcode, banc utilisé et adaptations.
3. **Exécution datée** : commandes exactes, résultats observés et codes de sortie lorsque disponibles.
4. **Scénarios** : nom du test, comportement attendu et résultat.
5. **Preuves** : extrait de sortie, journal nettoyé ou lien vers le job CI du commit testé.
6. **Limites** : tests bloqués, non exécutés, en attente et suites restant à valider.

Ne pas remplacer un résultat en attente par une réussite supposée. Lors d'une nouvelle exécution, ajouter une section datée et identifier le nouveau commit testé.
