# Documentation API REST

Cette documentation décrit l'API REST locale de Samourai Project Manager.

## Ouvrir Swagger UI

Ouvre `documentation/api/index.html` dans un navigateur. La page charge `openapi.yaml` et utilise Swagger UI depuis le CDN officiel `swagger-ui-dist`.

Si le navigateur bloque le chargement local du fichier YAML, sers le dossier avec un serveur statique :

```bash
cd documentation/api
python3 -m http.server 8090
```

Puis ouvre `http://localhost:8090`.

## API cible

Par défaut, l'application expose l'API sur :

```text
http://localhost:8080/api
```

Le port est configurable depuis la page Configuration de l'application.

## Formats

- Entree : `application/json`
- Sortie : `application/json`

Les endpoints de lecture n'ont pas besoin de body. Les endpoints `POST` et `PUT` exigent le header `Content-Type: application/json`.
