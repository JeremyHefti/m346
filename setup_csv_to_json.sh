#!/bin/bash

# Variablen
REGION="us-east-1"
IN_BUCKET_NAME="csv-to-json-in-$(date +%s)"
OUT_BUCKET_NAME="csv-to-json-out-$(date +%s)"
LAMBDA_FUNCTION_NAME="CsvToJsonConverter-$(date +%s)"
ROLE_ARN="arn:aws:iam::533539319174:role/LabRole"  # VORHANDENE ROLLE EINTRAGEN
ZIP_FILE="lambda_function_payload.zip"
LAMBDA_FILE="lambda_function.py"
CSV_FILE="sample.csv"
DOWNLOADED_JSON_FILE="converted_output.json"

# S3-Buckets erstellen
echo "Erstelle S3-Buckets..."
aws s3 mb "s3://${IN_BUCKET_NAME}" --region ${REGION}
aws s3 mb "s3://${OUT_BUCKET_NAME}" --region ${REGION}
echo "S3-Buckets ${IN_BUCKET_NAME} und ${OUT_BUCKET_NAME} wurden erstellt."

# Lambda-Funktion erstellen
echo "Erstelle Lambda-Funktion..."
cat > ${LAMBDA_FILE} <<EOL
import boto3
import csv
import json
import os

def lambda_handler(event, context):
    s3 = boto3.client('s3')
    in_bucket = event['Records'][0]['s3']['bucket']['name']
    in_key = event['Records'][0]['s3']['object']['key']
    
    # Output-Bucket aus Umgebungsvariablen
    out_bucket = os.environ['OUTPUT_BUCKET']
    out_key = in_key.replace('.csv', '.json')

    try:
        # Lade die CSV-Datei herunter
        response = s3.get_object(Bucket=in_bucket, Key=in_key)
        content = response['Body'].read().decode('utf-8').splitlines()

        # CSV zu JSON konvertieren
        reader = csv.DictReader(content)
        json_data = json.dumps(list(reader))

        # JSON-Datei im Out-Bucket speichern
        s3.put_object(Bucket=out_bucket, Key=out_key, Body=json_data)

        print(f"CSV {in_key} wurde zu JSON konvertiert und nach {out_bucket}/{out_key} hochgeladen.")
    except Exception as e:
        print(f"Fehler bei der Verarbeitung: {str(e)}")
EOL

# Lambda-Funktion zippen
zip ${ZIP_FILE} ${LAMBDA_FILE}

# Lambda-Funktion erstellen
aws lambda create-function \
  --function-name ${LAMBDA_FUNCTION_NAME} \
  --runtime python3.9 \
  --role ${ROLE_ARN} \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://${ZIP_FILE} \
  --region ${REGION} \
  --environment "Variables={OUTPUT_BUCKET=${OUT_BUCKET_NAME}}"

echo "Lambda-Funktion ${LAMBDA_FUNCTION_NAME} wurde erstellt."

# Lambda-Berechtigungen für S3 hinzufügen
aws lambda add-permission \
  --function-name ${LAMBDA_FUNCTION_NAME} \
  --principal s3.amazonaws.com \
  --statement-id s3invoke \
  --action "lambda:InvokeFunction" \
  --source-arn arn:aws:s3:::${IN_BUCKET_NAME} \
  --source-account 533539319174

# S3-Trigger hinzufügen
echo "Füge S3-Trigger hinzu..."
aws s3api put-bucket-notification-configuration --bucket ${IN_BUCKET_NAME} --notification-configuration "{
  \"LambdaFunctionConfigurations\": [
    {
      \"LambdaFunctionArn\": \"$(aws lambda get-function --function-name ${LAMBDA_FUNCTION_NAME} --query 'Configuration.FunctionArn' --output text)\",
      \"Events\": [\"s3:ObjectCreated:*\"] 
    }
  ]
}"

echo "Lambda-Trigger hinzugefügt: Uploads in ${IN_BUCKET_NAME} werden automatisch verarbeitet."

echo "Beispiel-CSV-Datei erstellt: ${CSV_FILE}"

# CSV-Datei in den In-Bucket hochladen
echo "Lade CSV-Datei '${CSV_FILE}' in den Bucket '${IN_BUCKET_NAME}' hoch..."
aws s3 cp ${CSV_FILE} s3://${IN_BUCKET_NAME}/
echo "CSV-Datei erfolgreich hochgeladen."

# Warte auf die Verarbeitung der Lambda-Funktion
echo "Warte auf die Verarbeitung..."
sleep 10  # Wartezeit für die Verarbeitung (je nach Bedarf anpassen)

# JSON-Datei aus dem Output-Bucket herunterladen
echo "Lade JSON-Datei aus dem Output-Bucket herunter..."

# Überprüfen, ob der Output-Bucket Dateien enthält
OUTPUT_KEY=$(aws s3api list-objects --bucket ${OUT_BUCKET_NAME} --query "Contents[0].Key" --output text)

if [ "$OUTPUT_KEY" == "None" ] || [ -z "$OUTPUT_KEY" ]; then
  echo "Keine JSON-Datei im Output-Bucket gefunden!"
  exit 1
fi

# Datei herunterladen
aws s3 cp s3://${OUT_BUCKET_NAME}/${OUTPUT_KEY} ${DOWNLOADED_JSON_FILE}

if [ $? -eq 0 ]; then
  echo "JSON-Datei erfolgreich heruntergeladen: ${DOWNLOADED_JSON_FILE}"
else
  echo "Fehler beim Herunterladen der JSON-Datei!"
  exit 1
fi

# JSON-Datei anzeigen
echo "Inhalt der JSON-Datei:"
cat ${DOWNLOADED_JSON_FILE}

echo "Setup abgeschlossen!"

