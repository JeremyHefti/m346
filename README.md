# AWS CSV to JSON Setup Script Documentation

Dieses Dokument beschreibt die Funktionsweise und den Einsatz des Bash-Skripts zur Einrichtung eines automatisierten Workflows zur Konvertierung von CSV-Dateien zu JSON mit AWS-Diensten.

---

## Übersicht

Das Skript:
- Erstellt zwei S3-Buckets: einen für die Eingabe von CSV-Dateien und einen für die Ausgabe von JSON-Dateien.
- Implementiert eine AWS Lambda-Funktion, die die Konvertierung durchführt.
- Fügt einen S3-Trigger hinzu, der die Lambda-Funktion automatisch bei Uploads auslöst.

---

## Voraussetzungen

- **AWS CLI**: Installiert und konfiguriert.
- **IAM-Rolle mit Berechtigungen**:
  - Zugriff auf S3 (Lesen/Schreiben).
  - Berechtigungen zur Ausführung von Lambda-Funktionen.
- **Bash**: Das Skript ist auf UNIX-ähnlichen Systemen lauffähig.

---

## Verwendung

### 1. Skript ausführen

Klone das Repository und führe den folgenden Command aus:

```bash
bash setup.sh
```

### 2. Ablauf

1. **S3-Buckets erstellen**: Zwei S3-Buckets werden erstellt, deren Namen automatisch mit einem Zeitstempel versehen werden, um Kollisionen zu vermeiden.
2. **Lambda-Funktion bereitstellen**: Eine Python-basierte Lambda-Funktion wird erstellt und bereitgestellt.
3. **Trigger hinzufügen**: Ein S3-Event-Trigger wird konfiguriert, um die Lambda-Funktion bei jedem neuen Objekt im Input-Bucket auszulösen.
4. **Trigger hinzufügen**: Ein S3-Bucket wird konfiguriert, in den die Lambda Funktion das JSON file ablegt.

### 3. CSV-Datei hochladen

Lade eine CSV-Datei in den Input-Bucket hoch:

```bash
aws s3 cp example.csv s3://<IN_BUCKET_NAME>
```

Die Lambda-Funktion wird automatisch ausgeführt und die konvertierte JSON-Datei im Output-Bucket gespeichert.

### 4. Ergebnis abrufen

Lade die JSON-Datei aus dem Output-Bucket herunter:

```bash
aws s3 cp s3://<OUT_BUCKET_NAME>/example.json ./example.json
```

---

## Skript-Parameter

### Variablen

- **REGION**: Die AWS-Region, in der die Ressourcen erstellt werden (Standard: `us-east-1`).
- **IN_BUCKET_NAME**: Name des Input-S3-Buckets (automatisch generiert).
- **OUT_BUCKET_NAME**: Name des Output-S3-Buckets (automatisch generiert).
- **LAMBDA_FUNCTION_NAME**: Name der Lambda-Funktion (Standard: `CsvToJsonConverter`).
- **ROLE_ARN**: ARN der IAM-Rolle, die die Lambda-Funktion verwenden soll.

---

## Beispiel Lambda-Code

Der Lambda-Code wird zur Laufzeit des Skripts generiert und hat folgende Funktionalität:

1. **CSV-Daten lesen**: Die Datei wird aus dem Input-Bucket geladen.
2. **Konvertierung**: Die CSV-Daten werden in JSON umgewandelt.
3. **Speicherung**: Die JSON-Daten werden in den Output-Bucket geschrieben.

```python
import boto3
import csv
import json
import os

def lambda_handler(event, context):
    s3 = boto3.client('s3')
    in_bucket = event['Records'][0]['s3']['bucket']['name']
    in_key = event['Records'][0]['s3']['object']['key']
    out_bucket = os.environ['OUTPUT_BUCKET']
    out_key = in_key.replace('.csv', '.json')

    response = s3.get_object(Bucket=in_bucket, Key=in_key)
    content = response['Body'].read().decode('utf-8').splitlines()

    reader = csv.DictReader(content)
    json_data = json.dumps(list(reader))

    s3.put_object(Bucket=out_bucket, Key=out_key, Body=json_data)

    print(f"CSV {in_key} wurde zu JSON konvertiert und nach {out_bucket}/{out_key} hochgeladen.")
```

---

## Fehlersuche

### Häufige Fehler

1. **Ungültige Rolle**:
   - Stelle sicher, dass `ROLE_ARN` auf eine gültige IAM-Rolle zeigt.

2. **Fehlende Berechtigungen**:
   - Vergewissere dich, dass die IAM-Rolle Zugriff auf S3 und Lambda hat.

3. **Ungültige CSV-Dateien**:
   - Prüfe, ob die Datei korrekt formatiert ist und ein gültiges Trennzeichen verwendet wird.

### Logs prüfen

Nutze AWS CloudWatch, um die Logs der Lambda-Funktion zu überprüfen:

```bash
aws logs tail /aws/lambda/CsvToJsonConverter
```

---

## Autor

**Leon Höfferer & Jeremy Hefti**

Dieses Dokument wurde erstellt, um den Einsatz des Skripts zu vereinfachen und seine Funktionen zu erläutern.
