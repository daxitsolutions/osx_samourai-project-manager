# Samourai Project Manager

Application macOS native en SwiftUI pour piloter un portefeuille de projets avec une logique de gouvernance, de delivery et de traçabilité.

Le projet centralise dans une seule interface :

- le suivi des projets et de leur santé
- la planification macro et les actions PM
- les ressources et leurs affectations
- les risques, livrables, événements et décisions
- les réunions, comptes-rendus et synthèses de gouvernance
- les sauvegardes et restaurations locales

## Vue d'ensemble

Samourai Project Manager est pensé comme un cockpit de pilotage projet sur macOS, sans backend ni dépendances externes.

L'application s'appuie sur :

- une interface SwiftUI native
- un stockage local JSON
- des imports métier pour ressources et risques
- une portée par projet principal pour naviguer plus vite dans le quotidien d'un PM/PMO
- des exports ciblés pour reporting, ressources et sauvegardes

## Fonctionnalités principales

### Pilotage et portefeuille

- Dashboard de synthèse sur le projet actif
- liste des projets avec création, édition et suivi de santé
- métriques d'avancement, risques critiques et livrables à surveiller
- sélection persistante d'un projet principal pour filtrer les vues transverses

### Planning et exécution

- plan projet avec activités macro
- rattachement des actions PM aux activités
- suivi de progression à partir des actions terminées
- vue Actions PM avec priorités, échéances, filtres et recherche

### Ressources

- annuaire ressources global
- vues grille et tableau
- édition inline sur plusieurs colonnes
- recherche multicritère, y compris par domaine email avec `@`
- import de ressources depuis `.xlsx`, `.csv`, `.tsv` ou texte tabulé
- export Excel de la vue complète ou d'une sélection

### Risques et livrables

- registre global des risques, avec ou sans projet associé
- import massif des risques depuis fichiers tabulaires ou Excel
- édition rapide des champs clés
- vue transverse des livrables du portefeuille
- suivi simple de complétion des livrables

### Événements, réunions et décisions

- journal d'événements projet
- registre des réunions avec transcript et résumé saisi
- glisser-déposer de fichiers `.ics` ou texte pour préremplir une réunion
- registre des décisions avec historique de révision et commentaires
- liens entre décisions, réunions, événements et ressources impactées

### Reporting et sauvegardes

- génération de synthèses de gouvernance
- archivage des rapports produits
- export des rapports en `.md`, `.txt` et `.pdf`
- export d'un backup complet de l'application
- restauration depuis `.samourai-backup` ou `.json`

### Configuration et debug

- réglage de la taille de texte
- panneau debug contextuel
- historisation optionnelle des traces dans un fichier texte
- suppression complète des données depuis l'application

## Stack technique

- Swift 6.2
- SwiftUI
- Observation avec `@Observable`
- cible macOS 15+
- aucune dépendance externe SPM

## Structure du dépôt

- `Package.swift` : définition du package Swift
- `Sources/SamouraiProjectManagerApp/App` : point d'entrée et état global d'interface
- `Sources/SamouraiProjectManagerApp/Views` : vues SwiftUI par domaine métier
- `Sources/SamouraiProjectManagerApp/Models` : modèles métier
- `Sources/SamouraiProjectManagerApp/Support` : store, persistance, import/export, seed de démonstration
- `run.sh` : build + lancement GUI local
- `package.sh` : création du bundle `.app`

## Lancer l'application

### Prérequis

- macOS 15 ou plus récent
- Xcode ou une toolchain Swift 6.2 installée

### Lancement recommandé

```bash
./run.sh
```

Le script :

- compile l'application en debug
- ferme les anciennes instances si besoin
- lance l'interface graphique
- tente de redonner le focus à la fenêtre

### Lancement avec logs détaillés

```bash
./run.sh --debug
```

En mode debug, les logs sont écrits dans `/tmp` avec un nom du type `SamouraiProjectManager-run-YYYYMMDD-HHMMSS.log`.

### Build manuel

```bash
swift build
swift run SamouraiProjectManager
```

## Générer une application `.app`

```bash
./package.sh
```

Ce script :

- build le projet en `release`
- génère `SamouraiProjectManager.app`
- crée le `Info.plist`
- applique une signature ad-hoc locale si possible
- installe le bundle dans `/Applications`

Pour générer le bundle sans installation automatique :

```bash
./package.sh --no-install
```

## Données et persistance

Les données de travail sont stockées localement dans :

```text
~/Documents/SamouraiProjectManager/projects.json
```

L'application crée aussi des sauvegardes automatiques dans :

```text
~/Documents/SamouraiProjectManager/auto-backups/
```

Notes utiles :

- l'ancien emplacement `~/Library/Application Support/...` est migré automatiquement si un fichier legacy existe
- la sauvegarde finale est forcée à la fermeture de l'application
- les données sont nettoyées à la lecture pour éviter de conserver des références cassées

## Données de démonstration

Lors du premier lancement sur une base vide, l'application initialise automatiquement :

- 2 projets de démonstration
- plusieurs risques et livrables associés
- 3 ressources exemple

Cela permet de prendre l'outil en main immédiatement.

## Formats gérés

- import ressources : `.xlsx`, `.csv`, `.tsv`, `.txt`
- export ressources : `.xlsx`
- import risques : `.xlsx`, `.csv`, `.tsv`, `.txt`
- export reporting : `.md`, `.txt`, `.pdf`
- backup / restauration : `.samourai-backup`, `.json`
- préremplissage réunions par glisser-déposer : `.ics`, texte brut

## Limites actuelles

- application locale uniquement, sans mode multi-utilisateur
- pas d'authentification ni gestion de rôles
- pas d'intégration native avec des outils externes de ticketing ou de calendrier
- pas de génération IA embarquée pour les résumés de réunion, seulement un champ de saisie
- pas de backend ou d'API distante

## Positionnement du projet

Ce dépôt contient une application de pilotage très orientée usage interne PM/PMO, avec une préférence claire pour :

- la lisibilité opérationnelle
- le stockage simple et robuste
- des workflows desktop rapides
- une gouvernance explicite plutôt qu'une couche d'automatisation opaque
