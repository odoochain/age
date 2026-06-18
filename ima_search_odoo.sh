#!/bin/bash
cd ~/.claude/skills/ima-skill

CLIENT_ID=$(cat ~/.config/ima/client_id)
API_KEY=$(cat ~/.config/ima/api_key)
OPTS="{\"clientId\":\"$CLIENT_ID\",\"apiKey\":\"$API_KEY\"}"

echo "=== Search: odoo开发 ==="
node ima_api.cjs "openapi/wiki/v1/search_knowledge_base" "{\"query\":\"odoo开发\",\"cursor\":\"\",\"limit\":20}" "$OPTS" 2>&1
