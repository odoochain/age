#!/bin/bash
cd ~/.claude/skills/ima-skill

CLIENT_ID=$(cat ~/.config/ima/client_id)
API_KEY=$(cat ~/.config/ima/api_key)
OPTS="{\"clientId\":\"$CLIENT_ID\",\"apiKey\":\"$API_KEY\"}"

FILE_PATH="${FILE_PATH:-D:/dev/lawgraph/age-source/BUILD_WINDOWS.md}"
KB_IDS=("${KB_IDS[@]:-}")  # Set via env: export KB_IDS=("id1" "id2")
KB_NAMES=("${KB_NAMES[@]:-}")  # Set via env: export KB_NAMES=("name1" "name2")

echo "=== Step 1: Preflight check ==="
PREFLIGHT=$(node knowledge-base/scripts/preflight-check.cjs --file "$FILE_PATH" 2>&1)
echo "$PREFLIGHT" | head -5

FILE_NAME=$(echo "$PREFLIGHT" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(d.file_name)")
FILE_EXT=$(echo "$PREFLIGHT" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(d.file_ext)")
FILE_SIZE=$(echo "$PREFLIGHT" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(String(d.file_size))")
MEDIA_TYPE=$(echo "$PREFLIGHT" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(String(d.media_type))")
CONTENT_TYPE=$(echo "$PREFLIGHT" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(d.content_type)")

echo "file=$FILE_NAME size=$FILE_SIZE type=$MEDIA_TYPE"

for i in 0 1; do
  KB_ID="${KB_IDS[$i]}"
  KB_NAME="${KB_NAMES[$i]}"
  echo ""
  echo "=== Uploading to [$KB_NAME] ==="

  # Check repeated names
  node ima_api.cjs "openapi/wiki/v1/check_repeated_names" "{
    \"params\": [{\"name\": \"$FILE_NAME\", \"media_type\": $MEDIA_TYPE}],
    \"knowledge_base_id\": \"$KB_ID\"
  }" "$OPTS" 2>&1 | head -3

  # Create media
  CREATE_RESP=$(node ima_api.cjs "openapi/wiki/v1/create_media" "{
    \"file_name\": \"$FILE_NAME\",
    \"file_size\": $FILE_SIZE,
    \"content_type\": \"$CONTENT_TYPE\",
    \"knowledge_base_id\": \"$KB_ID\",
    \"file_ext\": \"$FILE_EXT\"
  }" "$OPTS" 2>&1)

  CREATE_CODE=$(echo "$CREATE_RESP" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(String(d.code))")
  if [ "$CREATE_CODE" != "0" ]; then
    echo "create_media failed: $(echo "$CREATE_RESP" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(d.msg)")"
    continue
  fi

  MEDIA_ID=$(echo "$CREATE_RESP" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(d.data.media_id)")
  SECRET_ID=$(echo "$CREATE_RESP" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(d.data.cos_credential.secret_id)")
  SECRET_KEY=$(echo "$CREATE_RESP" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(d.data.cos_credential.secret_key)")
  TOKEN=$(echo "$CREATE_RESP" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(d.data.cos_credential.token)")
  BUCKET=$(echo "$CREATE_RESP" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(d.data.cos_credential.bucket_name)")
  REGION=$(echo "$CREATE_RESP" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(d.data.cos_credential.region)")
  COS_KEY=$(echo "$CREATE_RESP" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(d.data.cos_credential.cos_key)")
  START_TIME=$(echo "$CREATE_RESP" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(String(d.data.cos_credential.start_time))")
  EXPIRED_TIME=$(echo "$CREATE_RESP" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(String(d.data.cos_credential.expired_time))")

  # COS Upload
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
    --timeout 300000 2>&1 | tail -3
  UPLOAD_EXIT=$?

  if [ $UPLOAD_EXIT -ne 0 ]; then
    echo "COS upload failed for [$KB_NAME]!"
    continue
  fi

  # Add knowledge
  ADD_RESP=$(node ima_api.cjs "openapi/wiki/v1/add_knowledge" "{
    \"media_type\": $MEDIA_TYPE,
    \"media_id\": \"$MEDIA_ID\",
    \"title\": \"$FILE_NAME\",
    \"knowledge_base_id\": \"$KB_ID\",
    \"file_info\": {
      \"cos_key\": \"$COS_KEY\",
      \"file_size\": $FILE_SIZE,
      \"file_name\": \"$FILE_NAME\"
    }
  }" "$OPTS" 2>&1)

  ADD_CODE=$(echo "$ADD_RESP" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(String(d.code))")
  if [ "$ADD_CODE" = "0" ]; then
    echo "[$KB_NAME] Upload success!"
  else
    echo "[$KB_NAME] add_knowledge failed: $(echo "$ADD_RESP" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));process.stdout.write(d.msg)")"
  fi
done

echo ""
echo "=== All done ==="
