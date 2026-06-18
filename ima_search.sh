#!/bin/bash
export PATH=/c/Program\ Files/Git/bin:$PATH
cd ~/.claude/skills/ima-skill

CLIENT_ID=$(cat ~/.config/ima/client_id)
API_KEY=$(cat ~/.config/ima/api_key)
OPTS="{\"clientId\":\"$CLIENT_ID\",\"apiKey\":\"$API_KEY\"}"

# Search for knowledge base "010"
node ima_api.cjs "openapi/wiki/v1/search_knowledge_base" "{\"query\":\"010\",\"cursor\":\"\",\"limit\":20}" "$OPTS"
