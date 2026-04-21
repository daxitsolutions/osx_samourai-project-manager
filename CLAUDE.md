# CLAUDE.md — Samourai Project Manager

> Référence architecturale et guide de développement pour Claude Code.
> Toute modification importante doit être cohérente avec ce document.

---

## 🗂️ Projet

**Nom :** Samourai Project Manager
**Type :** Application native macOS — gestion de portefeuille de projets professionnels
**Stack :** Swift 6.2 + SwiftUI — macOS 15 Sequoia+ — Zéro dépendance externe
**Langue UI :** Français (labels, alertes, textes d'aide, noms de variables métier)

---

## ⚙️ Commandes

```bash
./run.sh                  # Lancement en développement
./run.sh --debug          # Lancement avec logs dans /tmp
./package.sh              # Build + packaging .app (installe dans /Applications)
./package.sh --no-install # Build sans installation
swift run SamouraiProjectManager  # Via SPM directement
```

> Aucun test target ni linter configuré pour l'instant.

---

## Architecture Globale

**Flux de données :**
Les Vues (UI) lisent l'état via `@Environment` depuis le `SamouraiStore` (Single Source of Truth).
Toute mutation passe par `SamouraiStore`, qui gère la logique métier et la persistance (`projects.json`).

```
[Vue SwiftUI]
    ↓ lit via @Environment
[SamouraiStore]  ←→  [SamouraiPersistence (actor async)]
                              ↕
             ~/Library/Application Support/SamouraiProjectManager/projects.json
```

---

## Composants Clés

| Fichier / Module | Rôle | Usage |
|---|---|---|
| `App/SamouraiProjectManagerApp.swift` | Point d'entrée. Configure les services, injecte `AppState`, `SamouraiStore`, `SamouraiTypography` via `.environment()`. | Lancement et branchement du contexte global. |
| `App/AppState.swift` | État de navigation (sélection courante : Projet, Ressource, Risque…), thème, offset de police dynamique. Persiste via `UserDefaults`. | Savoir où l'utilisateur se trouve ; personnalisation de l'affichage. |
| `Support/SamouraiStore.swift` | **Hub de données unique (~4 300 lignes).** Encapsule l'acteur `SamouraiPersistence` pour l'I/O asynchrone JSON. `loadIfNeeded()` hydrate au démarrage ; premier lancement → seed démo. Backup/restore (120 rolling backups, format `SamouraiBackupEnvelope v1`). Import CSV/XLSX (`ResourceImportService`, `RiskImportService`) avec déduplication. Export XLSX (`ResourceExportService`). | Point de contrôle unique pour toutes les mutations. |
| `Models/SamouraiModels.swift` | Toutes les structs `Codable / Hashable` (~2 500 lignes) : `Project`, `Resource`, `Risk`, `Deliverable`, `ProjectActivity`, `ProjectEvent`, `ProjectAction`, `ProjectMeeting`, `ProjectDecision`, `GovernanceReport`, scénarios de planning, baselines, scope changes, évaluations de performance… | Modélisation précise du domaine. Toute donnée doit transiter par ces structs. |
| `Support/SamouraiTypography.swift` | Logique de dimensionnement des polices pour le Dynamic Type macOS. Partagée via `@Environment`. | Accessibilité et qualité visuelle sur tous les écrans. |
| `Support/SamouraiColorTheme.swift` | Design tokens : brand blue/green, danger red, warning yellow, neutral grays. | Cohérence visuelle globale. |
| `Views/SamouraiDesignSystem.swift` | Composants réutilisables : `SamouraiSectionCard`, `SamouraiMetricTile`, `SamouraiEmptyStateCard`, `AppSidebarSectionRow`… | Bibliothèque de briques UI partagées. |

---

## Vues (Modules UI)

Navigation pilotée par `Views/AppShellView.swift` → `NavigationSplitView` (Sidebar + Zone de Détail).
Les sections Sidebar sont regroupées en bandes lettrées (A–E).

| Module | Fichiers | Rôle | Objectif utilisateur |
|---|---|---|---|
| **AppShell** | `Views/AppShellView.swift` | Coquille de haut niveau, orchestrée par le `NavigationSplitView`. | Expérience principale : Sidebar + zone de détail. |
| **Dashboard** | `Views/Dashboard/*View.swift` | Vue agrégée : alertes, tâches récentes, métriques clés. | Répondre à "Comment va le projet ?" en un coup d'œil. |
| **Projects** | `Views/Projects/*View.swift` | Détails d'un projet spécifique : jalons, liens. | Gérer toutes les composantes d'un projet. Point central du travail métier. |
| **Resources** | `Views/Resources/*View.swift` | Gestion et suivi des actifs du projet. | S'assurer que les ressources sont correctement suivies et liées au contexte. |
| **Risks** | `Views/Risks/*View.swift` | Enregistrement et suivi des risques identifiés. | Vigilance continue sur les menaces potentielles. |
| **Deliverables** | `Views/Deliverables/*View.swift` | Tableau de bord suivi des livrables et de leur avancement. | Contrôle de la production vs. planning. |
| **Decisions** | `Views/Decisions/*View.swift` | Enregistrement et revue des décisions critiques. | Piste d'audit inaltérable des arbitrages importants. |
| **Events** | `Views/Events/*View.swift` | Événements importants liés au projet (revues, jalons franchis…). | Traçabilité chronologique et contexte des événements. |
| **Meetings** | `Views/Meetings/*View.swift` | Registre des réunions (ordre du jour, participants, compte-rendu). | Contexte humain et artefacts de discussion pour chaque décision. |
| **Actions** | `Views/Actions/*View.swift` | Suivi des actions issues des réunions et décisions. | S'assurer que rien ne tombe dans les oublis. |
| **Reporting** | `Views/Reporting/*View.swift` | Génération des rapports finaux (potentiellement XLSX). | Production des sorties formelles du projet. |
| **Planning** | `Views/Planning/*View.swift` | Scénarios de planning, baselines, scope changes. | Modélisation et comparaison des trajectoires du projet. |
| **Testing** | `Views/Testing/*View.swift` | Placeholder. | À définir. |

---

## Patterns à Respecter

```swift
// ✅ Les vues lisent directement depuis @Environment — pas de ViewModels intermédiaires
@Environment(SamouraiStore.self) private var store
@Environment(AppState.self) private var appState

// ✅ Navigation par mutation d'IDs sur AppState — pas de NavigationPath
appState.selectedProjectId = project.id

// ✅ Toutes les opérations store sont asynchrones, wrappées dans Task
Button("Sauvegarder") {
    Task { await store.saveProject(project) }
}

// ✅ Toutes les mutations appellent immédiatement await store.save()
```

---

## Règles de Développement (Strictes)

Tu es un expert senior en développement d'applications macOS sur Apple Silicon (M1/M2/M3/M4/M5).

### Stack & Cibles
- **SwiftUI en priorité absolue** — AppKit uniquement si techniquement inévitable et clairement justifié
- **macOS 15 Sequoia minimum** (ou la dernière version disponible)
- **Swift 6.2** — concurrence stricte, `Sendable`, acteurs

### Qualité du Code
- Code moderne, propre, lisible, bien commenté
- Suivre les best practices Apple 2025/2026 : `@Observable`, `@State`, `@Environment`, `@AppStorage`, `NavigationStack`, `WindowGroup`, `.task`, `async/await`
- Optimiser pour la performance et la batterie sur Apple Silicon
- Respecter le design system macOS natif : sidebar, toolbar, menu bar, look & feel natif
- Utiliser les dernières APIs Apple pertinentes (SwiftData si applicable, TipKit, etc.)

### Pour chaque réponse
- Fournir du code complet, prêt à l'emploi
- Expliquer les choix architecturaux et les décisions importantes
- Suggérer des améliorations si pertinent
- Anticiper les edge cases et appliquer les best practices

---

## Workflow d'Orchestration

### 1. Plan First
- Entrer en mode planification pour **toute tâche non triviale** (3+ étapes ou décision architecturale)
- Si quelque chose déraille : **STOP et re-planifier** — ne pas continuer à avancer en aveugle
- Utiliser le mode plan pour les étapes de vérification, pas seulement pour la construction
- Écrire des specs détaillées en amont pour réduire l'ambiguïté

### 2. Stratégie Subagents
- Utiliser des subagents pour garder la fenêtre de contexte principale propre
- Déléguer la recherche, l'exploration et les analyses parallèles aux subagents
- Un seul focus par subagent

### 3. Boucle d'Auto-Amélioration
- Après **toute correction** de l'utilisateur : mettre à jour `tasks/lessons.md` avec le pattern
- Écrire des règles qui préviennent la même erreur à l'avenir
- Revoir les leçons pertinentes au début de chaque session

### 4. Vérification avant "Done"
- Ne jamais marquer une tâche comme terminée sans prouver que ça fonctionne
- Se poser la question : *"Un staff engineer validerait-il ce code ?"*
- Vérifier les logs / tester le comportement / démontrer la correction

### 5. Exiger l'Élégance (Équilibrée)
- Pour les changements non triviaux : se demander *"Y a-t-il une approche plus élégante ?"*
- Si un fix semble hacky → implémenter la solution propre
- Ne pas sur-ingéniérer les corrections simples et évidentes

### 6. Correction de Bugs Autonome
- Rapport de bug reçu → corriger directement, sans demander à être guidé pas à pas
- Pointer les logs/erreurs/tests, puis les résoudre
- Corriger les CI/tests en échec de manière autonome

---

## Gestion des Tâches

1. **Planifier d'abord** → écrire le plan dans `tasks/todo.md` avec des items cochables
2. **Valider le plan** avant de commencer l'implémentation
3. **Suivre l'avancement** → cocher les items au fur et à mesure
4. **Expliquer les changements** → résumé haut niveau à chaque étape
5. **Documenter les résultats** → ajouter une section de revue dans `tasks/todo.md`
6. **Capturer les leçons** → mettre à jour `tasks/lessons.md` après chaque correction

---

*Prêt. Construisons une application macOS exemplaire.*