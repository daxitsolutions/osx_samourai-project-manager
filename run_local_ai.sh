#!/bin/bash

# 1. Configuration des variables d'environnement
# On utilise 'export' pour que les variables soient accessibles par le processus 'claude'
export ANTHROPIC_BASE_URL="http://127.0.0.1:1234"
export ANTHROPIC_AUTH_TOKEN="sk-lm-wSFTQwHO:n9sNTDAWVka1HOqBmrlW"

# 2. Mise à jour du PATH (si ce n'est pas déjà fait)
# Cette ligne ajoute le chemin local à ton .bashrc pour les futures sessions
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    export PATH="$HOME/.local/bin:$PATH"
    echo "Le PATH a été mis à jour."
fi

# 3. Lancement du modèle
# On utilise le modèle Gemma-4 via l'interface Claude (compatible OpenAI/Anthropic local)
echo "Lancement de Gemma-4-31b..."
claude --model google/gemma-4-31b
