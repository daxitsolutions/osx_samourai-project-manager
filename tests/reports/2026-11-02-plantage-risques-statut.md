# Plantage dans Risques — 2 novembre 2026

## Périmètre

Rapport de plantage transmis par l'utilisateur, sans issue GitHub associée. L'application installée (UUID `BE70F2BC-65F6-3CE5-B5E2-856AF46713C8`, compilée depuis le checkout local `3f9a486`) s'arrête dans la section Risques.

Base : `f68d421` (`main`). Commit testé : `391719d7e5297aadb00bf620f8df76c066aafc8d` (branche `codex/fix-risk-status-menu-crash`). Le fichier `Views/Risks/RiskRegisterView.swift` est identique entre `3f9a486` et `main` : `main` est donc touché aussi.

### Rapport de plantage

- **Exception** : `EXC_BREAKPOINT` (SIGTRAP), dans `EnvironmentValues.subscript.getter` appelé depuis `EnvironmentBox.update`. C'est la lecture d'un objet `@Environment(Type.self)` absent.
- **Moment** : pendant un layout de `NSHostingView` déclenché par la synchronisation du défilement (`_NSScrollingConcurrentMainThreadSynchronizer`), 3 s après le lancement.

### Cause

Tous les objets d'environnement sont injectés à la racine de l'unique scène, et aucune vue n'est hébergée manuellement par AppKit. Dans la section Risques, la colonne « Statut » de la `Table` affiche `RiskStatusMenu`, un `Menu` dont le label est `RiskStatusBadge`. Ces deux vues lisaient `@Environment(AppState.self)` uniquement pour obtenir la langue de l'interface. Or elles sont rendues dans des cellules de `Table` et dans un label de `Menu`, hébergés par AppKit. Une cellule créée pendant le défilement peut ne pas recevoir l'objet, d'où l'arrêt.

Recherche des autres composants qui lisent l'environnement et sont utilisés dans une `Table` ou comme label de `Menu` : aucun autre cas trouvé. `ActionSortHeader` et `ActionHistoryInlinePanel` ne sont pas dans une `Table` SwiftUI. `ProjectListRow` et `ResourceRoleCoverageRow` sont des lignes de liste ou de carte.

### Correctif

`RiskStatusMenu` et `RiskStatusBadge` reçoivent `language: AppLanguage` en paramètre et ne lisent plus l'environnement. La table leur passe `appState.interfaceLanguage`.

## Environnement

macOS 26.6.2, Apple Silicon, Xcode 27.2 (27B52), Apple Swift 6.4.2, `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

## Exécution locale — 2 novembre 2026

| Commande | Résultat |
|---|---|
| `swift test --parallel`, sur `391719d` | **réussi**, sortie 0, `Test run with 47 tests in 10 suites passed after 0.895 seconds.` |
| `swift build -c release --product SamouraiProjectManager` | **réussi**, `Build complete! (38,39 s)` |

| Test `RiskStatusMenuRenderingTests` | Comportement vérifié | Résultat |
|---|---|---|
| `statusMenuRendersWithoutEnvironmentObjects` (×4 statuts) | Le menu de statut, hébergé dans un `NSHostingView` sans aucun objet d'environnement (comme une cellule AppKit), se met en page sans plantage. | réussi |
| `badgeUsesTheGivenLanguage` | Le badge se rend avec `ImageRenderer` sans environnement. | réussi |

Contrôle de mutation : la lecture `@Environment(AppState.self)` a été réintroduite dans `RiskStatusBadge`, puis `swift test --filter RiskStatusMenuRenderingTests`. **Échec attendu** : le processus de test s'arrête avec le signal 5 et « Fatal error: No Observable object of type AppState found ». C'est la même signature que le rapport de plantage. Le fichier a été rétabli avant la suite réussie.

## Limites et checks CI

- Le rapport de plantage ne nomme pas la vue fautive. Le lien avec `RiskStatusMenu` repose sur le contexte (section Risques, layout pendant le défilement), sur l'absence d'autre lecteur d'environnement dans une cellule de `Table`, et sur la signature reproduite par la mutation. Le parcours réel (ouvrir Risques et faire défiler la table) n'a **pas été exécuté** par l'agent.
- L'application installée vient du checkout local `3f9a486`. Elle ne contiendra le correctif qu'après réinstallation depuis une version qui l'inclut.
- Checks GitHub : **en attente** à la rédaction ; à vérifier sur la tête de la PR avant fusion.
