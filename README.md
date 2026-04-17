# osx_samourai-project-manager

Première itération d'une application macOS native SwiftUI pour piloter des projets selon une méthode "Samourai" :

- gouvernance forte côté cadrage / planning
- delivery piloté de façon pragmatique et ciblée
- maîtrise des risques, livrables et arbitrages

## Lancer localement

Le dépôt est structuré comme un Swift Package macOS 15+.

```bash
mkdir -p .build/clang-cache .build/swift-cache
CLANG_MODULE_CACHE_PATH=$PWD/.build/clang-cache \
SWIFT_MODULECACHE_PATH=$PWD/.build/swift-cache \
swift run SamouraiProjectManager
```

## Contenu de la première itération

- dashboard portefeuille
- registre des risques transverse avec attributs métier détaillés et import
- pilotage des livrables
- gestion CRUD des ressources humaines
- import des ressources depuis un fichier Excel `.xlsx`, `.csv` ou `.tsv`
- espace projet avec détail, ajout de risques et livrables
- affectation optionnelle des ressources aux projets
- seed de données démo pour tester immédiatement l'application
