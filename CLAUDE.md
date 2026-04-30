# CLAUDE.md — Samourai Project Manager

> Référence architecturale et guide de développement pour Claude Code.
> Toute modification importante doit être cohérente avec ce document.

---

## Projet

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

SAMOURAI_ARCHITECTURE_AI_SPEC
version=2026-04-23
language=fr

[global_rules]
max_lines_per_file=400
ai_context_unit=feature_slice
no_models_refactor=true
no_design_system_refactor=true

[workspace_root]
path=/Users/Dax/Documents/GitHub/osx_samourai-project-manager/Sources/SamouraiProjectManagerApp

[layers]
App=bootstrap+navigation+shell
Views=ui_by_domain
Support=stores+services+persistence
Models=domain_types

[entrypoints]
app_state=/Users/Dax/Documents/GitHub/osx_samourai-project-manager/Sources/SamouraiProjectManagerApp/App/AppState.swift
app_boot=/Users/Dax/Documents/GitHub/osx_samourai-project-manager/Sources/SamouraiProjectManagerApp/App/SamouraiProjectManagerApp.swift
app_shell=/Users/Dax/Documents/GitHub/osx_samourai-project-manager/Sources/SamouraiProjectManagerApp/Views/AppShellView.swift

[store_architecture_target]
coordinator_store=SamouraiStore
substores_required=ProjectStore,ResourceStore,ActivityStore,RiskStore,MiscStore
coordinator_responsibilities=instantiate_substores,persistence_json,backup_restore,swiftui_injection,facade_api
view_access_pattern=views_use_store_facade_only

[store_architecture_current]
coordinator=/Users/Dax/Documents/GitHub/osx_samourai-project-manager/Sources/SamouraiProjectManagerApp/Support/SamouraiStore.swift
resource_substore_main=/Users/Dax/Documents/GitHub/osx_samourai-project-manager/Sources/SamouraiProjectManagerApp/Support/Stores/ResourceStore.swift
resource_substore_crud=/Users/Dax/Documents/GitHub/osx_samourai-project-manager/Sources/SamouraiProjectManagerApp/Support/Stores/ResourceStore+CRUD.swift
resource_substore_analytics=/Users/Dax/Documents/GitHub/osx_samourai-project-manager/Sources/SamouraiProjectManagerApp/Support/Stores/ResourceStore+Analytics.swift
resource_substore_import=/Users/Dax/Documents/GitHub/osx_samourai-project-manager/Sources/SamouraiProjectManagerApp/Support/Stores/ResourceStore+Import.swift
resource_substore_import_helpers=/Users/Dax/Documents/GitHub/osx_samourai-project-manager/Sources/SamouraiProjectManagerApp/Support/Stores/ResourceStore+ImportReviewHelpers.swift
pending_substores=ProjectStore,ActivityStore,RiskStore,MiscStore

[views_architecture_target]
resources_dir=Views/Resources
resources_files=ResourceWorkspaceView.swift,ResourceEditorSheet.swift,ResourceImportReviewSheet.swift,ResourceProfilingCards.swift
projects_dir=Views/Projects
projects_files=ProjectDetailView.swift,ProjectTimelineView.swift,ProjectActivityEditorSheet.swift,ProjectDropdowns.swift
app_dir=Views/App
app_files=AppShellView.swift,BackupWorkspaceView.swift,ConfigurationWorkspaceView.swift

[views_architecture_current]
resource_workspace=/Users/Dax/Documents/GitHub/osx_samourai-project-manager/Sources/SamouraiProjectManagerApp/Views/Resources/ResourceWorkspaceView.swift
resource_editor_sheet=/Users/Dax/Documents/GitHub/osx_samourai-project-manager/Sources/SamouraiProjectManagerApp/Views/Resources/ResourceEditorSheet.swift
project_detail=/Users/Dax/Documents/GitHub/osx_samourai-project-manager/Sources/SamouraiProjectManagerApp/Views/Projects/ProjectDetailView.swift
project_timeline=/Users/Dax/Documents/GitHub/osx_samourai-project-manager/Sources/SamouraiProjectManagerApp/Views/Projects/ProjectTimelineView.swift
project_activity_editor=/Users/Dax/Documents/GitHub/osx_samourai-project-manager/Sources/SamouraiProjectManagerApp/Views/Projects/ProjectActivityEditorSheet.swift
project_dropdowns=/Users/Dax/Documents/GitHub/osx_samourai-project-manager/Sources/SamouraiProjectManagerApp/Views/Projects/ProjectDropdowns.swift
app_shell=/Users/Dax/Documents/GitHub/osx_samourai-project-manager/Sources/SamouraiProjectManagerApp/Views/AppShellView.swift
backup_workspace=/Users/Dax/Documents/GitHub/osx_samourai-project-manager/Sources/SamouraiProjectManagerApp/Views/App/BackupWorkspaceView.swift
configuration_workspace=/Users/Dax/Documents/GitHub/osx_samourai-project-manager/Sources/SamouraiProjectManagerApp/Views/App/ConfigurationWorkspaceView.swift
pending_view_splits=ResourceImportReviewSheet,ResourceProfilingCards

[dependency_rules]
Views_to_Store=SamouraiStore_facade_only
SamouraiStore_to_Substores=allowed
Substores_to_Views=forbidden
Substores_to_Models=allowed
Substores_to_Persistence=forbidden_direct
Persistence_owner=SamouraiStore

[persistence_contract]
format=json
primary_file=ApplicationSupport/SamouraiProjectManager/projects.json
auto_backups=ApplicationSupport/SamouraiProjectManager/auto-backups
backup_envelope=SamouraiBackupEnvelope
restore_validation=SamouraiStore.validatedDatabase

[ai_prompt_file_sets]
feature_add_activity_budget=/Users/Dax/Documents/GitHub/osx_samourai-project-manager/Sources/SamouraiProjectManagerApp/Support/Stores/ActivityStore.swift,/Users/Dax/Documents/GitHub/osx_samourai-project-manager/Sources/SamouraiProjectManagerApp/Models/ActivityModels.swift,/Users/Dax/Documents/GitHub/osx_samourai-project-manager/Sources/SamouraiProjectManagerApp/Views/Projects/ProjectActivityEditorSheet.swift
fix_resource_csv_import=/Users/Dax/Documents/GitHub/osx_samourai-project-manager/Sources/SamouraiProjectManagerApp/Views/Resources/ResourceImportReviewSheet.swift,/Users/Dax/Documents/GitHub/osx_samourai-project-manager/Sources/SamouraiProjectManagerApp/Support/ResourceImportService.swift,/Users/Dax/Documents/GitHub/osx_samourai-project-manager/Sources/SamouraiProjectManagerApp/Models/ResourceModels.swift
resource_crud=/Users/Dax/Documents/GitHub/osx_samourai-project-manager/Sources/SamouraiProjectManagerApp/Support/Stores/ResourceStore.swift,/Users/Dax/Documents/GitHub/osx_samourai-project-manager/Sources/SamouraiProjectManagerApp/Support/Stores/ResourceStore+CRUD.swift,/Users/Dax/Documents/GitHub/osx_samourai-project-manager/Sources/SamouraiProjectManagerApp/Views/Resources/ResourceEditorSheet.swift

[migration_sequence]
step_1=extract_ResourceEditorSheet_done
step_2=extract_ProjectActivityEditorSheet_and_ProjectTimelineView_done
step_3=create_ResourceStore_and_delegate_from_SamouraiStore_done
step_4=extract_remaining_resource_view_components_pending
step_5=introduce_ProjectStore_pending
step_6=introduce_ActivityStore_pending
step_7=introduce_RiskStore_pending
step_8=introduce_MiscStore_pending

[non_goals]
models_folder_changes=forbidden
design_system_changes=forbidden


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
- Anticiper les edge cases et appliquer les best practices
- Pas d'explication, code uniquement

---

# UI / UX 

## Directives pour les créations des écrans 'modals' de type création et édition des objets.
1. Architecture de l'Information & Alignement

    Alignement Vertical (Top-Aligned Labels) : Systématisez le placement des libellés au-dessus des champs de saisie. Cela crée un chemin visuel direct et facilite le remplissage sur mobile ou écrans étroits.

    Grille de Proximité : Regroupez les éléments liés par thématique (ex: regrouper "Statut", "Sévérité" et "Échéance" sous une section "Métadonnées") pour réduire la charge cognitive visible dans image_f090b9.jpg.

    Hiérarchie de Titrage : Utilisez une taille de police et une graisse distinctes pour le titre principal de l'action afin qu'il se détache immédiatement du reste du formulaire.

2. Standardisation des Composants de Saisie

    États d'Interaction : Définissez des styles visuels clairs pour chaque état d'un champ (Repos, Survol, Focus, Erreur, Désactivé). Le champ "Titre" dans image_f090b9.jpg montre un focus bleu qui doit être la norme partout.

    Micro-copie Guidée (Placeholders) : Ne laissez aucun champ vide de sens. Utilisez des textes d'exemple (ex: "Décrivez la tâche en quelques mots...") pour inciter à l'action.

    Saisie Prédictive : Pour les champs comme "Projet", privilégiez des listes déroulantes avec recherche intégrée si le nombre d'options dépasse 5 éléments.

3. Système de Feedback et de Validation

    Boutons d'Action (CTAs) :

        Primaire : Un seul bouton dominant par écran (ex: "Créer" en bleu).

        Secondaire : Boutons de contour ou texte seul (ex: "Annuler") pour éviter la compétition visuelle.

    Validation Contextuelle : N'attendez pas le clic sur "Créer" pour signaler une erreur. Validez les champs obligatoires dès que l'utilisateur change de zone (on-blur).

    Confirmation Visuelle : Comme suggéré pour le slider de image_f090b9.jpg, utilisez des codes couleurs sémantiques (Vert = Succès/Faible, Orange = Moyen, Rouge = Critique/Erreur) de manière consistante.

4. Accessibilité et Lisibilité (Dark Mode)

    Contraste des Textes : Assurez-vous que le texte gris sur fond sombre respecte les normes WCAG (contraste minimum de 4.5:1). Le texte secondaire dans le fond de image_f090b9.jpg gagnerait à être plus clair.

    Zones de Clic : Garantissez que chaque élément interactif (bouton, curseur de sévérité) a une zone de frappe d'au moins 44x44 pixels pour éviter les erreurs de manipulation.

    Navigation Clavier : La touche Tab doit permettre de parcourir l'écran dans un ordre logique (de haut en bas, de gauche à droite) et la touche Entrée doit déclencher l'action principale.

5. Cohérence des Espacements (Système de 8px)

    Espacement Standard : Utilisez des multiples de 8px pour toutes vos marges et paddings. Cela crée une harmonie visuelle automatique et simplifie le travail de développement.

        Exemple : 8px entre un libellé et son champ, 24px entre deux groupes de champs.