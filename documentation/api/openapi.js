window.SAMOURAI_OPENAPI_SPEC = {
  "openapi": "3.1.0",
  "info": {
    "title": "Samourai Project Manager REST API",
    "version": "1.0.0",
    "summary": "API REST locale pour exposer et modifier le modele de donnees Samourai Project Manager.",
    "description": "Cette specification documente l'API REST lancee depuis la page Configuration de l'application macOS.\n\nL'API est locale, sans authentification applicative pour le moment, et manipule directement les objets persistants de l'application. Les mutations declenchent la persistance automatique du store.\n\nToutes les requetes entrantes avec body doivent utiliser `Content-Type: application/json`. Les payloads non JSON sont rejetes avec une erreur standardisee.\n",
    "contact": {
      "name": "Dax IT Solutions"
    }
  },
  "servers": [
    {
      "url": "http://localhost:8080/api",
      "description": "Serveur local par defaut"
    },
    {
      "url": "http://localhost:{port}/api",
      "description": "Serveur local avec port configurable",
      "variables": {
        "port": {
          "default": "8080",
          "description": "Port configure dans la page Configuration de l'application."
        }
      }
    }
  ],
  "tags": [
    {
      "name": "Meta",
      "description": "Informations de service et de decouverte."
    },
    {
      "name": "Database",
      "description": "Snapshot complet de la base applicative."
    },
    {
      "name": "Projects",
      "description": "CRUD des projets."
    },
    {
      "name": "Resources",
      "description": "CRUD des ressources et de l'annuaire."
    },
    {
      "name": "Risks",
      "description": "CRUD des risques rattaches ou non a un projet."
    },
    {
      "name": "Actions",
      "description": "CRUD des actions PM."
    },
    {
      "name": "Decisions",
      "description": "CRUD des decisions."
    },
    {
      "name": "Events",
      "description": "CRUD des evenements."
    },
    {
      "name": "Meetings",
      "description": "CRUD des reunions."
    },
    {
      "name": "Deliverables",
      "description": "CRUD des livrables."
    },
    {
      "name": "Activities",
      "description": "CRUD des activites de planning."
    },
    {
      "name": "Scope",
      "description": "CRUD des elements de perimetre ScopeIn et ScopeOut."
    }
  ],
  "paths": {
    "/": {
      "get": {
        "tags": [
          "Meta"
        ],
        "summary": "Decouvrir l'API",
        "operationId": "getApiMetadata",
        "responses": {
          "200": {
            "description": "Metadata de l'API et liste des endpoints.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/RestApiMetadata"
                }
              }
            }
          }
        }
      }
    },
    "/status": {
      "get": {
        "tags": [
          "Meta"
        ],
        "summary": "Lire le statut du serveur REST",
        "operationId": "getApiStatus",
        "responses": {
          "200": {
            "description": "Etat courant du serveur.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/RestApiStatus"
                }
              }
            }
          }
        }
      }
    },
    "/database": {
      "get": {
        "tags": [
          "Database"
        ],
        "summary": "Exporter le snapshot complet",
        "operationId": "getDatabaseSnapshot",
        "responses": {
          "200": {
            "description": "Base complete serialisee.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/SamouraiDatabase"
                }
              }
            }
          }
        }
      },
      "put": {
        "tags": [
          "Database"
        ],
        "summary": "Remplacer le snapshot complet",
        "operationId": "replaceDatabaseSnapshot",
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/SamouraiDatabase"
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Base remplacee et normalisee.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/SamouraiDatabase"
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/InvalidJson"
          }
        }
      }
    },
    "/projects": {
      "get": {
        "tags": [
          "Projects"
        ],
        "summary": "Lister les projets",
        "operationId": "listProjects",
        "responses": {
          "200": {
            "description": "Liste des projets.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/Project"
                  }
                }
              }
            }
          }
        }
      },
      "post": {
        "tags": [
          "Projects"
        ],
        "summary": "Creer un projet",
        "operationId": "createProject",
        "requestBody": {
          "$ref": "#/components/requestBodies/ProjectBody"
        },
        "responses": {
          "201": {
            "description": "Projet cree.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/Project"
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/InvalidJson"
          },
          "409": {
            "$ref": "#/components/responses/Conflict"
          }
        }
      }
    },
    "/projects/{id}": {
      "parameters": [
        {
          "$ref": "#/components/parameters/UuidId"
        }
      ],
      "get": {
        "tags": [
          "Projects"
        ],
        "summary": "Lire un projet",
        "operationId": "getProject",
        "responses": {
          "200": {
            "description": "Projet trouve.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/Project"
                }
              }
            }
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      },
      "put": {
        "tags": [
          "Projects"
        ],
        "summary": "Remplacer un projet",
        "operationId": "replaceProject",
        "requestBody": {
          "$ref": "#/components/requestBodies/ProjectBody"
        },
        "responses": {
          "200": {
            "description": "Projet remplace.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/Project"
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/InvalidJson"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      },
      "delete": {
        "tags": [
          "Projects"
        ],
        "summary": "Supprimer un projet",
        "operationId": "deleteProject",
        "responses": {
          "204": {
            "description": "Projet supprime."
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      }
    },
    "/resources": {
      "get": {
        "tags": [
          "Resources"
        ],
        "summary": "Lister des ressources",
        "responses": {
          "200": {
            "description": "Liste des ressources.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/Resource"
                  }
                }
              }
            }
          }
        }
      },
      "post": {
        "tags": [
          "Resources"
        ],
        "summary": "Creer une ressource",
        "requestBody": {
          "$ref": "#/components/requestBodies/ResourceBody"
        },
        "responses": {
          "201": {
            "description": "Objet cree.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/Resource"
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/InvalidJson"
          },
          "409": {
            "$ref": "#/components/responses/Conflict"
          }
        }
      }
    },
    "/resources/{id}": {
      "parameters": [
        {
          "$ref": "#/components/parameters/UuidId"
        }
      ],
      "get": {
        "tags": [
          "Resources"
        ],
        "summary": "Lire une ressource",
        "responses": {
          "200": {
            "description": "Objet trouve.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/Resource"
                }
              }
            }
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      },
      "put": {
        "tags": [
          "Resources"
        ],
        "summary": "Remplacer une ressource",
        "requestBody": {
          "$ref": "#/components/requestBodies/ResourceBody"
        },
        "responses": {
          "200": {
            "description": "Objet remplace.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/Resource"
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/InvalidJson"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      },
      "delete": {
        "tags": [
          "Resources"
        ],
        "summary": "Supprimer une ressource",
        "responses": {
          "204": {
            "description": "Objet supprime."
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      }
    },
    "/resource-directory": {
      "get": {
        "tags": [
          "Resources"
        ],
        "summary": "Lister des ressources",
        "responses": {
          "200": {
            "description": "Liste des ressources.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/Resource"
                  }
                }
              }
            }
          }
        }
      },
      "post": {
        "tags": [
          "Resources"
        ],
        "summary": "Creer une ressource",
        "requestBody": {
          "$ref": "#/components/requestBodies/ResourceBody"
        },
        "responses": {
          "201": {
            "description": "Objet cree.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/Resource"
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/InvalidJson"
          },
          "409": {
            "$ref": "#/components/responses/Conflict"
          }
        }
      }
    },
    "/resource-directory/{id}": {
      "parameters": [
        {
          "$ref": "#/components/parameters/UuidId"
        }
      ],
      "get": {
        "tags": [
          "Resources"
        ],
        "summary": "Lire une ressource",
        "responses": {
          "200": {
            "description": "Objet trouve.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/Resource"
                }
              }
            }
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      },
      "put": {
        "tags": [
          "Resources"
        ],
        "summary": "Remplacer une ressource",
        "requestBody": {
          "$ref": "#/components/requestBodies/ResourceBody"
        },
        "responses": {
          "200": {
            "description": "Objet remplace.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/Resource"
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/InvalidJson"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      },
      "delete": {
        "tags": [
          "Resources"
        ],
        "summary": "Supprimer une ressource",
        "responses": {
          "204": {
            "description": "Objet supprime."
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      }
    },
    "/risks": {
      "get": {
        "tags": [
          "Risks"
        ],
        "summary": "Lister les risques",
        "operationId": "listRisks",
        "responses": {
          "200": {
            "description": "Risques avec leur projet de rattachement optionnel.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/ApiRiskRecord"
                  }
                }
              }
            }
          }
        }
      },
      "post": {
        "tags": [
          "Risks"
        ],
        "summary": "Creer un risque",
        "operationId": "createRisk",
        "requestBody": {
          "$ref": "#/components/requestBodies/ApiRiskRecordBody"
        },
        "responses": {
          "201": {
            "description": "Risque cree.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiRiskRecord"
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/InvalidJson"
          },
          "409": {
            "$ref": "#/components/responses/Conflict"
          }
        }
      }
    },
    "/risks/{id}": {
      "parameters": [
        {
          "$ref": "#/components/parameters/UuidId"
        }
      ],
      "get": {
        "tags": [
          "Risks"
        ],
        "summary": "Lire un risque",
        "operationId": "getRisk",
        "responses": {
          "200": {
            "description": "Risque trouve.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiRiskRecord"
                }
              }
            }
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      },
      "put": {
        "tags": [
          "Risks"
        ],
        "summary": "Remplacer un risque",
        "operationId": "replaceRisk",
        "requestBody": {
          "$ref": "#/components/requestBodies/ApiRiskRecordBody"
        },
        "responses": {
          "200": {
            "description": "Risque remplace.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiRiskRecord"
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/InvalidJson"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      },
      "delete": {
        "tags": [
          "Risks"
        ],
        "summary": "Supprimer un risque",
        "operationId": "deleteRisk",
        "responses": {
          "204": {
            "description": "Risque supprime."
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      }
    },
    "/actions": {
      "get": {
        "tags": [
          "Actions"
        ],
        "summary": "Lister des actions PM",
        "responses": {
          "200": {
            "description": "Liste des actions PM.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/ProjectAction"
                  }
                }
              }
            }
          }
        }
      },
      "post": {
        "tags": [
          "Actions"
        ],
        "summary": "Creer une action PM",
        "requestBody": {
          "$ref": "#/components/requestBodies/ProjectActionBody"
        },
        "responses": {
          "201": {
            "description": "Objet cree.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ProjectAction"
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/InvalidJson"
          },
          "409": {
            "$ref": "#/components/responses/Conflict"
          }
        }
      }
    },
    "/actions/{id}": {
      "parameters": [
        {
          "$ref": "#/components/parameters/UuidId"
        }
      ],
      "get": {
        "tags": [
          "Actions"
        ],
        "summary": "Lire une action PM",
        "responses": {
          "200": {
            "description": "Objet trouve.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ProjectAction"
                }
              }
            }
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      },
      "put": {
        "tags": [
          "Actions"
        ],
        "summary": "Remplacer une action PM",
        "requestBody": {
          "$ref": "#/components/requestBodies/ProjectActionBody"
        },
        "responses": {
          "200": {
            "description": "Objet remplace.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ProjectAction"
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/InvalidJson"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      },
      "delete": {
        "tags": [
          "Actions"
        ],
        "summary": "Supprimer une action PM",
        "responses": {
          "204": {
            "description": "Objet supprime."
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      }
    },
    "/pmactions": {
      "get": {
        "tags": [
          "Actions"
        ],
        "summary": "Lister des actions PM",
        "responses": {
          "200": {
            "description": "Liste des actions PM.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/ProjectAction"
                  }
                }
              }
            }
          }
        }
      },
      "post": {
        "tags": [
          "Actions"
        ],
        "summary": "Creer une action PM",
        "requestBody": {
          "$ref": "#/components/requestBodies/ProjectActionBody"
        },
        "responses": {
          "201": {
            "description": "Objet cree.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ProjectAction"
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/InvalidJson"
          },
          "409": {
            "$ref": "#/components/responses/Conflict"
          }
        }
      }
    },
    "/pmactions/{id}": {
      "parameters": [
        {
          "$ref": "#/components/parameters/UuidId"
        }
      ],
      "get": {
        "tags": [
          "Actions"
        ],
        "summary": "Lire une action PM",
        "responses": {
          "200": {
            "description": "Objet trouve.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ProjectAction"
                }
              }
            }
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      },
      "put": {
        "tags": [
          "Actions"
        ],
        "summary": "Remplacer une action PM",
        "requestBody": {
          "$ref": "#/components/requestBodies/ProjectActionBody"
        },
        "responses": {
          "200": {
            "description": "Objet remplace.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ProjectAction"
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/InvalidJson"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      },
      "delete": {
        "tags": [
          "Actions"
        ],
        "summary": "Supprimer une action PM",
        "responses": {
          "204": {
            "description": "Objet supprime."
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      }
    },
    "/decisions": {
      "get": {
        "tags": [
          "Decisions"
        ],
        "summary": "Lister les decisions",
        "operationId": "listDecisions",
        "responses": {
          "200": {
            "description": "Liste des decisions.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/ProjectDecision"
                  }
                }
              }
            }
          }
        }
      },
      "post": {
        "tags": [
          "Decisions"
        ],
        "summary": "Creer une decision",
        "operationId": "createDecision",
        "requestBody": {
          "$ref": "#/components/requestBodies/ProjectDecisionBody"
        },
        "responses": {
          "201": {
            "description": "Decision creee.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ProjectDecision"
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/InvalidJson"
          },
          "409": {
            "$ref": "#/components/responses/Conflict"
          }
        }
      }
    },
    "/decisions/{id}": {
      "parameters": [
        {
          "$ref": "#/components/parameters/UuidId"
        }
      ],
      "get": {
        "tags": [
          "Decisions"
        ],
        "summary": "Lire une decision",
        "operationId": "getDecision",
        "responses": {
          "200": {
            "description": "Decision trouvee.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ProjectDecision"
                }
              }
            }
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      },
      "put": {
        "tags": [
          "Decisions"
        ],
        "summary": "Remplacer une decision",
        "operationId": "replaceDecision",
        "requestBody": {
          "$ref": "#/components/requestBodies/ProjectDecisionBody"
        },
        "responses": {
          "200": {
            "description": "Decision remplacee.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ProjectDecision"
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/InvalidJson"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      },
      "delete": {
        "tags": [
          "Decisions"
        ],
        "summary": "Supprimer une decision",
        "operationId": "deleteDecision",
        "responses": {
          "204": {
            "description": "Decision supprimee."
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      }
    },
    "/events": {
      "get": {
        "tags": [
          "Events"
        ],
        "summary": "Lister les evenements",
        "operationId": "listEvents",
        "responses": {
          "200": {
            "description": "Liste des evenements.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/ProjectEvent"
                  }
                }
              }
            }
          }
        }
      },
      "post": {
        "tags": [
          "Events"
        ],
        "summary": "Creer un evenement",
        "operationId": "createEvent",
        "requestBody": {
          "$ref": "#/components/requestBodies/ProjectEventBody"
        },
        "responses": {
          "201": {
            "description": "Evenement cree.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ProjectEvent"
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/InvalidJson"
          },
          "409": {
            "$ref": "#/components/responses/Conflict"
          }
        }
      }
    },
    "/events/{id}": {
      "parameters": [
        {
          "$ref": "#/components/parameters/UuidId"
        }
      ],
      "get": {
        "tags": [
          "Events"
        ],
        "summary": "Lire un evenement",
        "operationId": "getEvent",
        "responses": {
          "200": {
            "description": "Evenement trouve.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ProjectEvent"
                }
              }
            }
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      },
      "put": {
        "tags": [
          "Events"
        ],
        "summary": "Remplacer un evenement",
        "operationId": "replaceEvent",
        "requestBody": {
          "$ref": "#/components/requestBodies/ProjectEventBody"
        },
        "responses": {
          "200": {
            "description": "Evenement remplace.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ProjectEvent"
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/InvalidJson"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      },
      "delete": {
        "tags": [
          "Events"
        ],
        "summary": "Supprimer un evenement",
        "operationId": "deleteEvent",
        "responses": {
          "204": {
            "description": "Evenement supprime."
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      }
    },
    "/meetings": {
      "get": {
        "tags": [
          "Meetings"
        ],
        "summary": "Lister les reunions",
        "operationId": "listMeetings",
        "responses": {
          "200": {
            "description": "Liste des reunions.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/ProjectMeeting"
                  }
                }
              }
            }
          }
        }
      },
      "post": {
        "tags": [
          "Meetings"
        ],
        "summary": "Creer une reunion",
        "operationId": "createMeeting",
        "requestBody": {
          "$ref": "#/components/requestBodies/ProjectMeetingBody"
        },
        "responses": {
          "201": {
            "description": "Reunion creee.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ProjectMeeting"
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/InvalidJson"
          },
          "409": {
            "$ref": "#/components/responses/Conflict"
          }
        }
      }
    },
    "/meetings/{id}": {
      "parameters": [
        {
          "$ref": "#/components/parameters/UuidId"
        }
      ],
      "get": {
        "tags": [
          "Meetings"
        ],
        "summary": "Lire une reunion",
        "operationId": "getMeeting",
        "responses": {
          "200": {
            "description": "Reunion trouvee.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ProjectMeeting"
                }
              }
            }
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      },
      "put": {
        "tags": [
          "Meetings"
        ],
        "summary": "Remplacer une reunion",
        "operationId": "replaceMeeting",
        "requestBody": {
          "$ref": "#/components/requestBodies/ProjectMeetingBody"
        },
        "responses": {
          "200": {
            "description": "Reunion remplacee.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ProjectMeeting"
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/InvalidJson"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      },
      "delete": {
        "tags": [
          "Meetings"
        ],
        "summary": "Supprimer une reunion",
        "operationId": "deleteMeeting",
        "responses": {
          "204": {
            "description": "Reunion supprimee."
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      }
    },
    "/deliverables": {
      "get": {
        "tags": [
          "Deliverables"
        ],
        "summary": "Lister des livrables",
        "responses": {
          "200": {
            "description": "Liste des livrables.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/ApiDeliverableRecord"
                  }
                }
              }
            }
          }
        }
      },
      "post": {
        "tags": [
          "Deliverables"
        ],
        "summary": "Creer un livrable",
        "requestBody": {
          "$ref": "#/components/requestBodies/ApiDeliverableRecordBody"
        },
        "responses": {
          "201": {
            "description": "Objet cree.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiDeliverableRecord"
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/InvalidJson"
          },
          "409": {
            "$ref": "#/components/responses/Conflict"
          }
        }
      }
    },
    "/deliverables/{id}": {
      "parameters": [
        {
          "$ref": "#/components/parameters/UuidId"
        }
      ],
      "get": {
        "tags": [
          "Deliverables"
        ],
        "summary": "Lire un livrable",
        "responses": {
          "200": {
            "description": "Objet trouve.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiDeliverableRecord"
                }
              }
            }
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      },
      "put": {
        "tags": [
          "Deliverables"
        ],
        "summary": "Remplacer un livrable",
        "requestBody": {
          "$ref": "#/components/requestBodies/ApiDeliverableRecordBody"
        },
        "responses": {
          "200": {
            "description": "Objet remplace.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiDeliverableRecord"
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/InvalidJson"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      },
      "delete": {
        "tags": [
          "Deliverables"
        ],
        "summary": "Supprimer un livrable",
        "responses": {
          "204": {
            "description": "Objet supprime."
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      }
    },
    "/delivrables": {
      "get": {
        "tags": [
          "Deliverables"
        ],
        "summary": "Lister des livrables",
        "responses": {
          "200": {
            "description": "Liste des livrables.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/ApiDeliverableRecord"
                  }
                }
              }
            }
          }
        }
      },
      "post": {
        "tags": [
          "Deliverables"
        ],
        "summary": "Creer un livrable",
        "requestBody": {
          "$ref": "#/components/requestBodies/ApiDeliverableRecordBody"
        },
        "responses": {
          "201": {
            "description": "Objet cree.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiDeliverableRecord"
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/InvalidJson"
          },
          "409": {
            "$ref": "#/components/responses/Conflict"
          }
        }
      }
    },
    "/delivrables/{id}": {
      "parameters": [
        {
          "$ref": "#/components/parameters/UuidId"
        }
      ],
      "get": {
        "tags": [
          "Deliverables"
        ],
        "summary": "Lire un livrable",
        "responses": {
          "200": {
            "description": "Objet trouve.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiDeliverableRecord"
                }
              }
            }
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      },
      "put": {
        "tags": [
          "Deliverables"
        ],
        "summary": "Remplacer un livrable",
        "requestBody": {
          "$ref": "#/components/requestBodies/ApiDeliverableRecordBody"
        },
        "responses": {
          "200": {
            "description": "Objet remplace.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiDeliverableRecord"
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/InvalidJson"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      },
      "delete": {
        "tags": [
          "Deliverables"
        ],
        "summary": "Supprimer un livrable",
        "responses": {
          "204": {
            "description": "Objet supprime."
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      }
    },
    "/activities": {
      "get": {
        "tags": [
          "Activities"
        ],
        "summary": "Lister les activites",
        "operationId": "listActivities",
        "responses": {
          "200": {
            "description": "Liste des activites.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/ProjectActivity"
                  }
                }
              }
            }
          }
        }
      },
      "post": {
        "tags": [
          "Activities"
        ],
        "summary": "Creer une activite",
        "operationId": "createActivity",
        "requestBody": {
          "$ref": "#/components/requestBodies/ProjectActivityBody"
        },
        "responses": {
          "201": {
            "description": "Activite creee.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ProjectActivity"
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/InvalidJson"
          },
          "409": {
            "$ref": "#/components/responses/Conflict"
          }
        }
      }
    },
    "/activities/{id}": {
      "parameters": [
        {
          "$ref": "#/components/parameters/UuidId"
        }
      ],
      "get": {
        "tags": [
          "Activities"
        ],
        "summary": "Lire une activite",
        "operationId": "getActivity",
        "responses": {
          "200": {
            "description": "Activite trouvee.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ProjectActivity"
                }
              }
            }
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      },
      "put": {
        "tags": [
          "Activities"
        ],
        "summary": "Remplacer une activite",
        "operationId": "replaceActivity",
        "requestBody": {
          "$ref": "#/components/requestBodies/ProjectActivityBody"
        },
        "responses": {
          "200": {
            "description": "Activite remplacee.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ProjectActivity"
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/InvalidJson"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      },
      "delete": {
        "tags": [
          "Activities"
        ],
        "summary": "Supprimer une activite",
        "operationId": "deleteActivity",
        "responses": {
          "204": {
            "description": "Activite supprimee."
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      }
    },
    "/scope-in": {
      "get": {
        "tags": [
          "Scope"
        ],
        "summary": "Lister les elements ScopeIn",
        "operationId": "listScopeIn",
        "responses": {
          "200": {
            "description": "Elements ScopeIn par projet.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/ApiScopeItem"
                  }
                }
              }
            }
          }
        }
      },
      "post": {
        "tags": [
          "Scope"
        ],
        "summary": "Ajouter un element ScopeIn",
        "operationId": "createScopeIn",
        "requestBody": {
          "$ref": "#/components/requestBodies/ApiScopeItemBody"
        },
        "responses": {
          "201": {
            "description": "Element ajoute.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiScopeItem"
                }
              }
            }
          }
        }
      }
    },
    "/scope-in/{projectID}/{index}": {
      "parameters": [
        {
          "$ref": "#/components/parameters/ProjectId"
        },
        {
          "$ref": "#/components/parameters/ScopeIndex"
        }
      ],
      "put": {
        "tags": [
          "Scope"
        ],
        "summary": "Remplacer un element ScopeIn",
        "operationId": "replaceScopeIn",
        "requestBody": {
          "$ref": "#/components/requestBodies/ApiScopeItemBody"
        },
        "responses": {
          "200": {
            "description": "Element remplace.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiScopeItem"
                }
              }
            }
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      },
      "delete": {
        "tags": [
          "Scope"
        ],
        "summary": "Supprimer un element ScopeIn",
        "operationId": "deleteScopeIn",
        "responses": {
          "204": {
            "description": "Element supprime."
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      }
    },
    "/scope-out": {
      "get": {
        "tags": [
          "Scope"
        ],
        "summary": "Lister les elements ScopeOut",
        "operationId": "listScopeOut",
        "responses": {
          "200": {
            "description": "Elements ScopeOut par projet.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/ApiScopeItem"
                  }
                }
              }
            }
          }
        }
      },
      "post": {
        "tags": [
          "Scope"
        ],
        "summary": "Ajouter un element ScopeOut",
        "operationId": "createScopeOut",
        "requestBody": {
          "$ref": "#/components/requestBodies/ApiScopeItemBody"
        },
        "responses": {
          "201": {
            "description": "Element ajoute.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiScopeItem"
                }
              }
            }
          }
        }
      }
    },
    "/scope-out/{projectID}/{index}": {
      "parameters": [
        {
          "$ref": "#/components/parameters/ProjectId"
        },
        {
          "$ref": "#/components/parameters/ScopeIndex"
        }
      ],
      "put": {
        "tags": [
          "Scope"
        ],
        "summary": "Remplacer un element ScopeOut",
        "operationId": "replaceScopeOut",
        "requestBody": {
          "$ref": "#/components/requestBodies/ApiScopeItemBody"
        },
        "responses": {
          "200": {
            "description": "Element remplace.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ApiScopeItem"
                }
              }
            }
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      },
      "delete": {
        "tags": [
          "Scope"
        ],
        "summary": "Supprimer un element ScopeOut",
        "operationId": "deleteScopeOut",
        "responses": {
          "204": {
            "description": "Element supprime."
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          }
        }
      }
    }
  },
  "components": {
    "parameters": {
      "UuidId": {
        "name": "id",
        "in": "path",
        "required": true,
        "description": "Identifiant UUID de l'objet.",
        "schema": {
          "type": "string",
          "format": "uuid"
        }
      },
      "ProjectId": {
        "name": "projectID",
        "in": "path",
        "required": true,
        "description": "Identifiant UUID du projet.",
        "schema": {
          "type": "string",
          "format": "uuid"
        }
      },
      "ScopeIndex": {
        "name": "index",
        "in": "path",
        "required": true,
        "description": "Index zero-based de l'element dans la liste du projet.",
        "schema": {
          "type": "integer",
          "minimum": 0
        }
      }
    },
    "requestBodies": {
      "ProjectBody": {
        "required": true,
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/Project"
            }
          }
        }
      },
      "ResourceBody": {
        "required": true,
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/Resource"
            }
          }
        }
      },
      "ApiRiskRecordBody": {
        "required": true,
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ApiRiskRecord"
            }
          }
        }
      },
      "ProjectActionBody": {
        "required": true,
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ProjectAction"
            }
          }
        }
      },
      "ProjectDecisionBody": {
        "required": true,
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ProjectDecision"
            }
          }
        }
      },
      "ProjectEventBody": {
        "required": true,
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ProjectEvent"
            }
          }
        }
      },
      "ProjectMeetingBody": {
        "required": true,
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ProjectMeeting"
            }
          }
        }
      },
      "ApiDeliverableRecordBody": {
        "required": true,
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ApiDeliverableRecord"
            }
          }
        }
      },
      "ProjectActivityBody": {
        "required": true,
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ProjectActivity"
            }
          }
        }
      },
      "ApiScopeItemBody": {
        "required": true,
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ApiScopeItem"
            }
          }
        }
      }
    },
    "responses": {
      "InvalidJson": {
        "description": "JSON invalide ou header Content-Type absent.",
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ErrorEnvelope"
            }
          }
        }
      },
      "NotFound": {
        "description": "Objet introuvable.",
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ErrorEnvelope"
            }
          }
        }
      },
      "Conflict": {
        "description": "Conflit, generalement un UUID deja existant.",
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ErrorEnvelope"
            }
          }
        }
      }
    },
    "schemas": {
      "Uuid": {
        "type": "string",
        "format": "uuid",
        "examples": [
          "00000000-0000-0000-0000-000000000000"
        ]
      },
      "IsoDateTime": {
        "type": "string",
        "format": "date-time",
        "description": "Date encodee en ISO 8601."
      },
      "RestApiMetadata": {
        "type": "object",
        "required": [
          "name",
          "inputFormat",
          "outputFormat",
          "endpoints"
        ],
        "properties": {
          "name": {
            "type": "string"
          },
          "inputFormat": {
            "type": "string",
            "example": "JSON (application/json)"
          },
          "outputFormat": {
            "type": "string",
            "example": "JSON (application/json)"
          },
          "endpoints": {
            "type": "array",
            "items": {
              "type": "string"
            }
          }
        }
      },
      "RestApiStatus": {
        "type": "object",
        "required": [
          "isRunning",
          "inputFormat",
          "outputFormat"
        ],
        "properties": {
          "isRunning": {
            "type": "boolean"
          },
          "port": {
            "type": "integer",
            "minimum": 1024,
            "maximum": 65535,
            "nullable": true
          },
          "baseURL": {
            "type": "string",
            "nullable": true,
            "example": "http://localhost:8080/api"
          },
          "inputFormat": {
            "type": "string"
          },
          "outputFormat": {
            "type": "string"
          }
        }
      },
      "ErrorEnvelope": {
        "type": "object",
        "required": [
          "error"
        ],
        "properties": {
          "error": {
            "type": "object",
            "required": [
              "code",
              "message"
            ],
            "properties": {
              "code": {
                "type": "string",
                "enum": [
                  "bad_request",
                  "invalid_json",
                  "not_found",
                  "conflict",
                  "unsupported_method",
                  "internal_error",
                  "store_unavailable",
                  "connection_error"
                ]
              },
              "message": {
                "type": "string"
              }
            }
          }
        }
      },
      "SamouraiDatabase": {
        "type": "object",
        "required": [
          "projects",
          "resources",
          "unassignedRisks",
          "activities",
          "events",
          "actions",
          "meetings",
          "decisions",
          "governanceReports"
        ],
        "properties": {
          "projects": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/Project"
            }
          },
          "resources": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/Resource"
            }
          },
          "unassignedRisks": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/Risk"
            }
          },
          "activities": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/ProjectActivity"
            }
          },
          "events": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/ProjectEvent"
            }
          },
          "actions": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/ProjectAction"
            }
          },
          "meetings": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/ProjectMeeting"
            }
          },
          "decisions": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/ProjectDecision"
            }
          },
          "governanceReports": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/GovernanceReportRecord"
            }
          }
        }
      },
      "Project": {
        "type": "object",
        "required": [
          "id",
          "name",
          "summary",
          "sponsor",
          "manager",
          "phase",
          "health",
          "deliveryMode",
          "startDate",
          "targetDate",
          "createdAt",
          "updatedAt",
          "risks",
          "deliverables",
          "scopeBaselines",
          "scopeChangeRequests",
          "planningScenarios",
          "planningBaselines",
          "testingPhases"
        ],
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "name": {
            "type": "string"
          },
          "summary": {
            "type": "string"
          },
          "sponsor": {
            "type": "string"
          },
          "manager": {
            "type": "string"
          },
          "phase": {
            "$ref": "#/components/schemas/ProjectPhase"
          },
          "health": {
            "$ref": "#/components/schemas/ProjectHealth"
          },
          "deliveryMode": {
            "$ref": "#/components/schemas/DeliveryMode"
          },
          "startDate": {
            "$ref": "#/components/schemas/IsoDateTime"
          },
          "targetDate": {
            "$ref": "#/components/schemas/IsoDateTime"
          },
          "createdAt": {
            "$ref": "#/components/schemas/IsoDateTime"
          },
          "updatedAt": {
            "$ref": "#/components/schemas/IsoDateTime"
          },
          "risks": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/Risk"
            }
          },
          "deliverables": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/Deliverable"
            }
          },
          "scopeDefinition": {
            "$ref": "#/components/schemas/ProjectScopeDefinition",
            "nullable": true
          },
          "scopeBaselines": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/ScopeBaseline"
            }
          },
          "scopeChangeRequests": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/ScopeChangeRequest"
            }
          },
          "planningScenarios": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/ProjectPlanningScenario"
            }
          },
          "planningBaselines": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/PlanningBaseline"
            }
          },
          "testingPhases": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/ProjectTestingPhase"
            }
          }
        }
      },
      "Resource": {
        "type": "object",
        "required": [
          "id",
          "fullName",
          "jobTitle",
          "department",
          "email",
          "phone",
          "engagement",
          "status",
          "allocationPercent",
          "assignedProjectIDs",
          "favoriteProjectIDs",
          "performanceEvaluations",
          "notes",
          "createdAt",
          "updatedAt"
        ],
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "fullName": {
            "type": "string"
          },
          "jobTitle": {
            "type": "string"
          },
          "department": {
            "type": "string"
          },
          "nom": {
            "type": "string",
            "nullable": true
          },
          "parentDescription": {
            "type": "string",
            "nullable": true
          },
          "primaryResourceRole": {
            "type": "string",
            "nullable": true
          },
          "resourceRoles": {
            "type": "string",
            "nullable": true
          },
          "organizationalResource": {
            "type": "string",
            "nullable": true
          },
          "competence1": {
            "type": "string",
            "nullable": true
          },
          "resourceCalendar": {
            "type": "string",
            "nullable": true
          },
          "resourceStartDate": {
            "$ref": "#/components/schemas/IsoDateTime",
            "nullable": true
          },
          "resourceFinishDate": {
            "$ref": "#/components/schemas/IsoDateTime",
            "nullable": true
          },
          "responsableOperationnel": {
            "type": "string",
            "nullable": true
          },
          "responsableInterne": {
            "type": "string",
            "nullable": true
          },
          "localisation": {
            "type": "string",
            "nullable": true
          },
          "typeDeRessource": {
            "type": "string",
            "nullable": true
          },
          "journeesTempsPartiel": {
            "type": "string",
            "nullable": true
          },
          "email": {
            "type": "string"
          },
          "phone": {
            "type": "string"
          },
          "engagement": {
            "$ref": "#/components/schemas/ResourceEngagement"
          },
          "status": {
            "$ref": "#/components/schemas/ResourceStatus"
          },
          "allocationPercent": {
            "type": "integer",
            "minimum": 0,
            "maximum": 100
          },
          "assignedProjectIDs": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/Uuid"
            }
          },
          "favoriteProjectIDs": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/Uuid"
            }
          },
          "performanceEvaluations": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/ResourcePerformanceEvaluation"
            }
          },
          "notes": {
            "type": "string"
          },
          "createdAt": {
            "$ref": "#/components/schemas/IsoDateTime"
          },
          "updatedAt": {
            "$ref": "#/components/schemas/IsoDateTime"
          }
        }
      },
      "ApiRiskRecord": {
        "type": "object",
        "required": [
          "risk"
        ],
        "properties": {
          "projectID": {
            "$ref": "#/components/schemas/Uuid",
            "nullable": true,
            "description": "Projet de rattachement. `null` cree ou conserve un risque non assigne."
          },
          "risk": {
            "$ref": "#/components/schemas/Risk"
          }
        }
      },
      "Risk": {
        "type": "object",
        "required": [
          "id",
          "title",
          "mitigation",
          "owner",
          "severity",
          "createdAt"
        ],
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "title": {
            "type": "string"
          },
          "mitigation": {
            "type": "string"
          },
          "owner": {
            "type": "string"
          },
          "severity": {
            "$ref": "#/components/schemas/RiskSeverity"
          },
          "dueDate": {
            "$ref": "#/components/schemas/IsoDateTime",
            "nullable": true
          },
          "createdAt": {
            "$ref": "#/components/schemas/IsoDateTime"
          },
          "externalID": {
            "type": "string",
            "nullable": true
          },
          "projectNames": {
            "type": "string",
            "nullable": true
          },
          "detectedBy": {
            "type": "string",
            "nullable": true
          },
          "assignedTo": {
            "type": "string",
            "nullable": true
          },
          "lastModifiedAt": {
            "$ref": "#/components/schemas/IsoDateTime",
            "nullable": true
          },
          "riskType": {
            "type": "string",
            "nullable": true
          },
          "response": {
            "type": "string",
            "nullable": true
          },
          "riskTitle": {
            "type": "string",
            "nullable": true
          },
          "riskOrigin": {
            "type": "string",
            "nullable": true
          },
          "impactDescription": {
            "type": "string",
            "nullable": true
          },
          "counterMeasure": {
            "type": "string",
            "nullable": true
          },
          "followUpComment": {
            "type": "string",
            "nullable": true
          },
          "proximity": {
            "type": "string",
            "nullable": true
          },
          "probability": {
            "type": "string",
            "nullable": true
          },
          "impactScope": {
            "type": "string",
            "nullable": true
          },
          "impactBudget": {
            "type": "string",
            "nullable": true
          },
          "impactPlanning": {
            "type": "string",
            "nullable": true
          },
          "impactResources": {
            "type": "string",
            "nullable": true
          },
          "impactTransition": {
            "type": "string",
            "nullable": true
          },
          "impactSecurityIT": {
            "type": "string",
            "nullable": true
          },
          "escalationLevel": {
            "type": "string",
            "nullable": true
          },
          "riskStatus": {
            "type": "string",
            "nullable": true
          },
          "score0to10": {
            "type": "number",
            "nullable": true
          },
          "history": {
            "type": "array",
            "nullable": true,
            "items": {
              "$ref": "#/components/schemas/RiskHistoryEntry"
            }
          }
        }
      },
      "ProjectAction": {
        "type": "object",
        "required": [
          "id",
          "title",
          "details",
          "priority",
          "status",
          "dueDate",
          "flow",
          "createdAt",
          "updatedAt",
          "isDone"
        ],
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "title": {
            "type": "string"
          },
          "details": {
            "type": "string"
          },
          "priority": {
            "$ref": "#/components/schemas/ActionPriority"
          },
          "status": {
            "$ref": "#/components/schemas/ActionStatus"
          },
          "dueDate": {
            "$ref": "#/components/schemas/IsoDateTime"
          },
          "flow": {
            "$ref": "#/components/schemas/ActionFlow"
          },
          "projectID": {
            "$ref": "#/components/schemas/Uuid",
            "nullable": true
          },
          "activityID": {
            "$ref": "#/components/schemas/Uuid",
            "nullable": true
          },
          "createdAt": {
            "$ref": "#/components/schemas/IsoDateTime"
          },
          "updatedAt": {
            "$ref": "#/components/schemas/IsoDateTime"
          },
          "isDone": {
            "type": "boolean"
          },
          "history": {
            "type": "array",
            "nullable": true,
            "items": {
              "$ref": "#/components/schemas/ActionHistoryEntry"
            }
          }
        }
      },
      "ProjectDecision": {
        "type": "object",
        "required": [
          "id",
          "sequenceNumber",
          "title",
          "details",
          "status",
          "meetingIDs",
          "eventIDs",
          "impactedResourceIDs",
          "history",
          "comments",
          "createdAt",
          "updatedAt"
        ],
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "sequenceNumber": {
            "type": "integer",
            "minimum": 1
          },
          "title": {
            "type": "string"
          },
          "details": {
            "type": "string"
          },
          "status": {
            "$ref": "#/components/schemas/DecisionStatus"
          },
          "projectID": {
            "$ref": "#/components/schemas/Uuid",
            "nullable": true
          },
          "meetingIDs": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/Uuid"
            }
          },
          "eventIDs": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/Uuid"
            }
          },
          "impactedResourceIDs": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/Uuid"
            }
          },
          "history": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/DecisionHistoryEntry"
            }
          },
          "comments": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/DecisionComment"
            }
          },
          "createdAt": {
            "$ref": "#/components/schemas/IsoDateTime"
          },
          "updatedAt": {
            "$ref": "#/components/schemas/IsoDateTime"
          }
        }
      },
      "ProjectEvent": {
        "type": "object",
        "required": [
          "id",
          "title",
          "details",
          "source",
          "priority",
          "happenedAt",
          "resourceIDs",
          "createdAt",
          "updatedAt"
        ],
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "title": {
            "type": "string"
          },
          "details": {
            "type": "string"
          },
          "source": {
            "type": "string"
          },
          "priority": {
            "$ref": "#/components/schemas/EventPriority"
          },
          "happenedAt": {
            "$ref": "#/components/schemas/IsoDateTime"
          },
          "projectID": {
            "$ref": "#/components/schemas/Uuid",
            "nullable": true
          },
          "resourceIDs": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/Uuid"
            }
          },
          "createdAt": {
            "$ref": "#/components/schemas/IsoDateTime"
          },
          "updatedAt": {
            "$ref": "#/components/schemas/IsoDateTime"
          }
        }
      },
      "ProjectMeeting": {
        "type": "object",
        "required": [
          "id",
          "title",
          "meetingAt",
          "durationMinutes",
          "mode",
          "organizer",
          "participants",
          "locationOrLink",
          "notes",
          "transcript",
          "aiSummary",
          "createdAt",
          "updatedAt"
        ],
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "title": {
            "type": "string"
          },
          "projectID": {
            "$ref": "#/components/schemas/Uuid",
            "nullable": true
          },
          "meetingAt": {
            "$ref": "#/components/schemas/IsoDateTime"
          },
          "durationMinutes": {
            "type": "integer",
            "minimum": 1
          },
          "mode": {
            "$ref": "#/components/schemas/MeetingMode"
          },
          "organizer": {
            "type": "string"
          },
          "participants": {
            "type": "string"
          },
          "locationOrLink": {
            "type": "string"
          },
          "notes": {
            "type": "string"
          },
          "transcript": {
            "type": "string"
          },
          "aiSummary": {
            "type": "string"
          },
          "createdAt": {
            "$ref": "#/components/schemas/IsoDateTime"
          },
          "updatedAt": {
            "$ref": "#/components/schemas/IsoDateTime"
          }
        }
      },
      "ApiDeliverableRecord": {
        "type": "object",
        "required": [
          "projectID",
          "deliverable"
        ],
        "properties": {
          "projectID": {
            "$ref": "#/components/schemas/Uuid"
          },
          "deliverable": {
            "$ref": "#/components/schemas/Deliverable"
          }
        }
      },
      "Deliverable": {
        "type": "object",
        "required": [
          "id",
          "title",
          "details",
          "owner",
          "dueDate",
          "isDone",
          "phase",
          "isMilestone",
          "acceptanceCriteria",
          "createdAt"
        ],
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "title": {
            "type": "string"
          },
          "details": {
            "type": "string"
          },
          "owner": {
            "type": "string"
          },
          "dueDate": {
            "$ref": "#/components/schemas/IsoDateTime"
          },
          "isDone": {
            "type": "boolean"
          },
          "phase": {
            "$ref": "#/components/schemas/DeliverablePhase"
          },
          "parentDeliverableID": {
            "$ref": "#/components/schemas/Uuid",
            "nullable": true
          },
          "isMilestone": {
            "type": "boolean"
          },
          "acceptanceCriteria": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/DeliverableAcceptanceCriterion"
            }
          },
          "integratedSourceProjectID": {
            "$ref": "#/components/schemas/Uuid",
            "nullable": true
          },
          "createdAt": {
            "$ref": "#/components/schemas/IsoDateTime"
          }
        }
      },
      "ProjectActivity": {
        "type": "object",
        "required": [
          "id",
          "projectID",
          "scenarioID",
          "displayOrder",
          "hierarchyLevel",
          "title",
          "estimatedStartDate",
          "estimatedEndDate",
          "predecessorActivityIDs",
          "isMilestone",
          "linkedDeliverableIDs",
          "createdAt",
          "updatedAt"
        ],
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "projectID": {
            "$ref": "#/components/schemas/Uuid"
          },
          "scenarioID": {
            "$ref": "#/components/schemas/Uuid"
          },
          "parentActivityID": {
            "$ref": "#/components/schemas/Uuid",
            "nullable": true
          },
          "displayOrder": {
            "type": "integer",
            "minimum": 0,
            "description": "Ordre d'affichage manuel de l'activité dans son scénario."
          },
          "hierarchyLevel": {
            "$ref": "#/components/schemas/ActivityHierarchyLevel"
          },
          "title": {
            "type": "string"
          },
          "estimatedStartDate": {
            "$ref": "#/components/schemas/IsoDateTime"
          },
          "estimatedEndDate": {
            "$ref": "#/components/schemas/IsoDateTime"
          },
          "actualEndDate": {
            "$ref": "#/components/schemas/IsoDateTime",
            "nullable": true
          },
          "predecessorActivityIDs": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/Uuid"
            }
          },
          "isMilestone": {
            "type": "boolean"
          },
          "linkedDeliverableIDs": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/Uuid"
            }
          },
          "createdAt": {
            "$ref": "#/components/schemas/IsoDateTime"
          },
          "updatedAt": {
            "$ref": "#/components/schemas/IsoDateTime"
          }
        }
      },
      "ApiScopeItem": {
        "type": "object",
        "required": [
          "projectID",
          "index",
          "value"
        ],
        "properties": {
          "projectID": {
            "$ref": "#/components/schemas/Uuid"
          },
          "index": {
            "type": "integer",
            "minimum": 0,
            "description": "Index zero-based dans la liste ScopeIn ou ScopeOut du projet."
          },
          "value": {
            "type": "string"
          }
        }
      },
      "ProjectScopeDefinition": {
        "type": "object",
        "required": [
          "inScopeItems",
          "outOfScopeItems",
          "linkedAnnexProjectIDs",
          "updatedAt"
        ],
        "properties": {
          "inScopeItems": {
            "type": "array",
            "items": {
              "type": "string"
            }
          },
          "outOfScopeItems": {
            "type": "array",
            "items": {
              "type": "string"
            }
          },
          "linkedAnnexProjectIDs": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/Uuid"
            }
          },
          "updatedAt": {
            "$ref": "#/components/schemas/IsoDateTime"
          }
        }
      },
      "ScopeBaseline": {
        "type": "object",
        "required": [
          "id",
          "milestoneLabel",
          "validatedBy",
          "scopeSnapshot",
          "deliverableSnapshots",
          "associatedChangeRequestIDs",
          "createdAt"
        ],
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "milestoneLabel": {
            "type": "string"
          },
          "validatedBy": {
            "type": "string"
          },
          "scopeSnapshot": {
            "$ref": "#/components/schemas/ProjectScopeDefinition"
          },
          "deliverableSnapshots": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/Deliverable"
            }
          },
          "associatedChangeRequestIDs": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/Uuid"
            }
          },
          "createdAt": {
            "$ref": "#/components/schemas/IsoDateTime"
          }
        }
      },
      "ScopeChangeRequest": {
        "type": "object",
        "required": [
          "id",
          "description",
          "impactPlanning",
          "impactResources",
          "impactRisks",
          "status",
          "requestedBy",
          "history",
          "createdAt",
          "updatedAt"
        ],
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "description": {
            "type": "string"
          },
          "impactPlanning": {
            "type": "string"
          },
          "impactResources": {
            "type": "string"
          },
          "impactRisks": {
            "type": "string"
          },
          "status": {
            "$ref": "#/components/schemas/ScopeChangeRequestStatus"
          },
          "requestedBy": {
            "type": "string"
          },
          "associatedBaselineID": {
            "$ref": "#/components/schemas/Uuid",
            "nullable": true
          },
          "history": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/ScopeChangeRequestHistoryEntry"
            }
          },
          "createdAt": {
            "$ref": "#/components/schemas/IsoDateTime"
          },
          "updatedAt": {
            "$ref": "#/components/schemas/IsoDateTime"
          }
        }
      },
      "ProjectPlanningScenario": {
        "type": "object",
        "required": [
          "id",
          "name",
          "createdAt",
          "updatedAt"
        ],
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "name": {
            "type": "string"
          },
          "createdAt": {
            "$ref": "#/components/schemas/IsoDateTime"
          },
          "updatedAt": {
            "$ref": "#/components/schemas/IsoDateTime"
          }
        }
      },
      "PlanningBaseline": {
        "type": "object",
        "required": [
          "id",
          "label",
          "validatedBy",
          "activitySnapshots",
          "createdAt"
        ],
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "label": {
            "type": "string"
          },
          "validatedBy": {
            "type": "string"
          },
          "scenarioID": {
            "$ref": "#/components/schemas/Uuid",
            "nullable": true
          },
          "activitySnapshots": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/PlanningBaselineActivitySnapshot"
            }
          },
          "createdAt": {
            "$ref": "#/components/schemas/IsoDateTime"
          }
        }
      },
      "PlanningBaselineActivitySnapshot": {
        "type": "object",
        "required": [
          "id",
          "title",
          "hierarchyLevel",
          "estimatedStartDate",
          "estimatedEndDate",
          "predecessorActivityIDs",
          "isMilestone"
        ],
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "title": {
            "type": "string"
          },
          "hierarchyLevel": {
            "$ref": "#/components/schemas/ActivityHierarchyLevel"
          },
          "estimatedStartDate": {
            "$ref": "#/components/schemas/IsoDateTime"
          },
          "estimatedEndDate": {
            "$ref": "#/components/schemas/IsoDateTime"
          },
          "predecessorActivityIDs": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/Uuid"
            }
          },
          "isMilestone": {
            "type": "boolean"
          }
        }
      },
      "ProjectTestingPhase": {
        "type": "object",
        "additionalProperties": true,
        "description": "Phase de test projet serialisee par l'application."
      },
      "GovernanceReportRecord": {
        "type": "object",
        "additionalProperties": true,
        "description": "Archive de reporting gouvernance serialisee par l'application."
      },
      "ResourcePerformanceEvaluation": {
        "type": "object",
        "required": [
          "id",
          "evaluatedAt",
          "milestone",
          "evaluator",
          "criterionScores",
          "weightedScore",
          "comment"
        ],
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "evaluatedAt": {
            "$ref": "#/components/schemas/IsoDateTime"
          },
          "milestone": {
            "type": "string"
          },
          "evaluator": {
            "type": "string"
          },
          "projectID": {
            "$ref": "#/components/schemas/Uuid",
            "nullable": true
          },
          "projectPhase": {
            "$ref": "#/components/schemas/ProjectPhase",
            "nullable": true
          },
          "criterionScores": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/ResourceCriterionScore"
            }
          },
          "weightedScore": {
            "type": "number",
            "minimum": 1,
            "maximum": 5
          },
          "comment": {
            "type": "string"
          }
        }
      },
      "ResourceCriterionScore": {
        "type": "object",
        "required": [
          "criterion",
          "score"
        ],
        "properties": {
          "criterion": {
            "$ref": "#/components/schemas/ResourceEvaluationCriterion"
          },
          "score": {
            "$ref": "#/components/schemas/ResourceEvaluationScale"
          }
        }
      },
      "RiskHistoryEntry": {
        "type": "object",
        "required": [
          "id",
          "kind",
          "date",
          "text"
        ],
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "kind": {
            "$ref": "#/components/schemas/HistoryEntryKind"
          },
          "date": {
            "$ref": "#/components/schemas/IsoDateTime"
          },
          "text": {
            "type": "string"
          }
        }
      },
      "ActionHistoryEntry": {
        "type": "object",
        "required": [
          "id",
          "kind",
          "date",
          "text"
        ],
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "kind": {
            "$ref": "#/components/schemas/HistoryEntryKind"
          },
          "date": {
            "$ref": "#/components/schemas/IsoDateTime"
          },
          "text": {
            "type": "string"
          }
        }
      },
      "DecisionHistoryEntry": {
        "type": "object",
        "required": [
          "id",
          "revision",
          "summary",
          "status",
          "snapshotTitle",
          "snapshotDetails",
          "recordedAt"
        ],
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "revision": {
            "type": "integer",
            "minimum": 1
          },
          "summary": {
            "type": "string"
          },
          "status": {
            "$ref": "#/components/schemas/DecisionStatus"
          },
          "snapshotTitle": {
            "type": "string"
          },
          "snapshotDetails": {
            "type": "string"
          },
          "recordedAt": {
            "$ref": "#/components/schemas/IsoDateTime"
          }
        }
      },
      "DecisionComment": {
        "type": "object",
        "required": [
          "id",
          "author",
          "body",
          "createdAt"
        ],
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "author": {
            "type": "string"
          },
          "body": {
            "type": "string"
          },
          "createdAt": {
            "$ref": "#/components/schemas/IsoDateTime"
          }
        }
      },
      "DeliverableAcceptanceCriterion": {
        "type": "object",
        "required": [
          "id",
          "text",
          "isValidated"
        ],
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "text": {
            "type": "string"
          },
          "isValidated": {
            "type": "boolean"
          }
        }
      },
      "ScopeChangeRequestHistoryEntry": {
        "type": "object",
        "required": [
          "id",
          "status",
          "actor",
          "note",
          "changedAt"
        ],
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "status": {
            "$ref": "#/components/schemas/ScopeChangeRequestStatus"
          },
          "actor": {
            "type": "string"
          },
          "note": {
            "type": "string"
          },
          "changedAt": {
            "$ref": "#/components/schemas/IsoDateTime"
          }
        }
      },
      "ProjectPhase": {
        "type": "string",
        "enum": [
          "cadrage",
          "planning",
          "delivery",
          "stabilisation"
        ]
      },
      "ProjectHealth": {
        "type": "string",
        "enum": [
          "green",
          "amber",
          "red"
        ]
      },
      "DeliveryMode": {
        "type": "string",
        "enum": [
          "waterfall",
          "hybrid",
          "agileFocused"
        ]
      },
      "ResourceEngagement": {
        "type": "string",
        "enum": [
          "internalEmployee",
          "externalConsultant",
          "freelancer"
        ]
      },
      "ResourceStatus": {
        "type": "string",
        "enum": [
          "active",
          "partiallyAvailable",
          "onLeave",
          "offboarded"
        ]
      },
      "ResourceEvaluationCriterion": {
        "type": "string",
        "enum": [
          "qualityDeliverable",
          "deadlineCompliance",
          "technicalFit",
          "reliability",
          "collaboration"
        ]
      },
      "ResourceEvaluationScale": {
        "type": "integer",
        "enum": [
          1,
          2,
          3,
          4,
          5
        ]
      },
      "RiskSeverity": {
        "type": "string",
        "enum": [
          "low",
          "medium",
          "high",
          "critical"
        ]
      },
      "RiskStatus": {
        "type": "string",
        "enum": [
          "A faire",
          "En cours",
          "Termine",
          "Annule",
          "Transforme en Incidence"
        ],
        "description": "Les valeurs applicatives originales peuvent contenir des accents."
      },
      "ActionPriority": {
        "type": "string",
        "enum": [
          "trivial",
          "minor",
          "major",
          "critical"
        ]
      },
      "ActionStatus": {
        "type": "string",
        "enum": [
          "todo",
          "inProgress",
          "done",
          "cancelled",
          "onHold"
        ]
      },
      "ActionFlow": {
        "type": "string",
        "enum": [
          "manuel",
          "automatique"
        ]
      },
      "DecisionStatus": {
        "type": "string",
        "enum": [
          "proposedUnderReview",
          "validated",
          "abandoned"
        ]
      },
      "EventPriority": {
        "type": "string",
        "enum": [
          "trivial",
          "minor",
          "major",
          "critical"
        ]
      },
      "MeetingMode": {
        "type": "string",
        "enum": [
          "physical",
          "virtual",
          "hybrid"
        ]
      },
      "DeliverablePhase": {
        "type": "string",
        "enum": [
          "cadrage",
          "design",
          "build",
          "tests",
          "deployment",
          "transition",
          "delivery"
        ]
      },
      "ActivityHierarchyLevel": {
        "type": "string",
        "enum": [
          "governancePortfolio",
          "program",
          "strategicProject",
          "criticalPhaseMilestone",
          "mainDeliverable",
          "activityTask",
          "subtaskAction",
          "archiveNote"
        ]
      },
      "ScopeChangeRequestStatus": {
        "type": "string",
        "enum": [
          "proposed",
          "reviewed",
          "approved",
          "rejected"
        ]
      },
      "HistoryEntryKind": {
        "type": "string",
        "enum": [
          "automatic",
          "manual"
        ]
      }
    }
  }
};
