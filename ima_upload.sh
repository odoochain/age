#!/bin/bash
cd ~/.claude/skills/ima-skill

CLIENT_ID=$(cat ~/.config/ima/client_id)
API_KEY=$(cat ~/.config/ima/api_key)
OPTS="{\"clientId\":\"$CLIENT_ID\",\"apiKey\":\"$API_KEY\"}"

KB_ID="${KB_ID:?Set KB_ID environment variable}"
FILE_PATH="D:/odoochain/odoo19/age-source/BUILD_WINDOWS.md"

echo "=== Step 1: Preflight check ==="
PREFLIGHT=$(node knowledge-base/scripts/preflight-check.cjs --file "$FILE_PATH" 2>&1)
echo "$PREFLIGHT"
PASS=$(echo "$PREFLIGHT" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(String(d.pass))")
if [ "$PASS" != "true" ]; then
  echo "Preflight failed!"
  exit 1
fi

FILE_NAME=$(echo "$PREFLIGHT" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(d.file_name)")
FILE_EXT=$(echo "$PREFLIGHT" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(d.file_ext)")
FILE_SIZE=$(echo "$PREFLIGHT" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(String(d.file_size))")
MEDIA_TYPE=$(echo "$PREFLIGHT" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(String(d.media_type))")
CONTENT_TYPE=$(echo "$PREFLIGHT" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(d.content_type)")

echo "file_name=$FILE_NAME, file_ext=$FILE_EXT, file_size=$FILE_SIZE, media_type=$MEDIA_TYPE"

echo "=== Step 2: Check repeated names ==="
node ima_api.cjs "openapi/wiki/v1/check_repeated_names" "{
  \"params\": [{\"name\": \"$FILE_NAME\", \"media_type\": $MEDIA_TYPE}],
  \"knowledge_base_id\": \"$KB_ID\"
}" "$OPTS" 2>&1

echo "=== Step 3: Create media ==="
CREATE_RESP=$(node ima_api.cjs "openapi/wiki/v1/create_media" "{
  \"file_name\": \"$FILE_NAME\",
  \"file_size\": $FILE_SIZE,
  \"content_type\": \"$CONTENT_TYPE\",
  \"knowledge_base_id\": \"$KB_ID\",
  \"file_ext\": \"$FILE_EXT\"
}" "$OPTS" 2>&1)
echo "$CREATE_RESP"

MEDIA_ID=$(echo "$CREATE_RESP" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(d.data.media_id)")
COS_URL=$(echo "$CREATE_RESP" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(d.data.url)")
SECRET_ID=$(echo "$CREATE_RESP" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(d.data.cos_credential.secret_id)")
SECRET_KEY=$(echo "$CREATE_RESP" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(d.data.cos_credential.secret_key)")
TOKEN=$(echo "$CREATE_RESP" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(d.data.cos_credential.token)")
BUCKET=$(echo "$CREATE_RESP" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(d.data.cos_credential.bucket_name)")
REGION=$(echo "$CREATE_RESP" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(d.data.cos_credential.region)")
COS_KEY=$(echo "$CREATE_RESP" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(d.data.cos_credential.cos_key)")
START_TIME=$(echo "$CREATE_RESP" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(String(d.data.cos_credential.start_time))")
EXPIRED_TIME=$(echo "$CREATE_RESP" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(String(d.data.cos_credential.expired_time))")

echo "media_id=$MEDIA_ID"

echo "=== Step 4: COS Upload ==="
node knowledge-base/scripts/cos-upload.cjs \
  --file "$FILE_PATH" \
  --secret-id "$SECRET_ID" \
  --secret-key "$SECRET_KEY" \
  --token "$TOKEN" \
  --bucket "$BUCKET" \
  --region "$REGION" \
  --cos-key "$COS_KEY" \
  --content-type "$CONTENT_TYPE" \
  --start-time "$START_TIME" \
  --expired-time "$EXPIRED_TIME" \
  --timeout 300000 2>&1
UPLOAD_EXIT=$?
echo "Upload exit: $UPLOAD_EXIT"
if [ $UPLOAD_EXIT -ne 0 ]; then
  echo "COS upload failed!"
  exit 1
fi

echo "=== Step 5: Add knowledge ==="
node ima_api.cjs "openapi/wiki/v1/add_knowledge" "{
  \"media_type\": $MEDIA_TYPE,
  \"media_id\": \"$MEDIA_ID\",
  \"title\": \"$FILE_NAME\",
  \"knowledge_base_id\": \"$KB_ID\",
  \"file_info\": {
    \"cos_key\": \"$COS_KEY\",
    \"file_size\": $FILE_SIZE,
    \"file_name\": \"$FILE_NAME\"
  }
}" "$OPTS" 2>&1

echo "=== Done ==="
