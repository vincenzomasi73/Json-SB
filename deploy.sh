#!/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
#  deploy.sh  –  Deploy Json-SB su Google Cloud Run
#
#  Prima esecuzione:
#    chmod +x deploy.sh
#    ./deploy.sh
#
#  Il progetto GCP "json-sb" viene creato automaticamente se non esiste.
#  Se richiesto, associa manualmente un account di fatturazione e rilancia.
# ──────────────────────────────────────────────────────────────────────────────

set -e

PROJECT_ID="json-sb"
SERVICE_NAME="json-sb"
REGION="europe-west1"
REPO="json-sb-repo"
IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO}/${SERVICE_NAME}"

echo "══════════════════════════════════════════════"
echo "  Json-SB – Deploy su Google Cloud Run"
echo "══════════════════════════════════════════════"
echo ""

# ── Verifica / crea progetto GCP ──────────────────
if ! gcloud projects describe "${PROJECT_ID}" &>/dev/null; then
    echo "📋  Creazione progetto GCP: ${PROJECT_ID}..."
    gcloud projects create "${PROJECT_ID}" --name="Json-SB"
    echo "✅  Progetto creato."
    echo ""
    echo "⚠️  ATTENZIONE: occorre associare un account di fatturazione."
    echo "    Apri nel browser:"
    echo "    https://console.cloud.google.com/billing/linkedaccount?project=${PROJECT_ID}"
    echo ""
    echo "    Premi INVIO dopo aver collegato l'account di fatturazione..."
    read -r
else
    echo "✅  Progetto ${PROJECT_ID} già esistente."
fi

# ── Imposta progetto corrente ─────────────────────
gcloud config set project "${PROJECT_ID}"

# ── Abilita API necessarie ────────────────────────
echo ""
echo "🔌  Abilitazione API (Cloud Run, Cloud Build, Container Registry)..."
gcloud services enable \
    run.googleapis.com \
    cloudbuild.googleapis.com \
    artifactregistry.googleapis.com \
    --project="${PROJECT_ID}"

# Crea repository Artifact Registry se non esiste
if ! gcloud artifacts repositories describe "${REPO}" --location="${REGION}" --project="${PROJECT_ID}" &>/dev/null; then
    echo "📦  Creazione Artifact Registry repository..."
    gcloud artifacts repositories create "${REPO}" \
        --repository-format=docker \
        --location="${REGION}" \
        --project="${PROJECT_ID}"
fi

echo ""
echo "🔧  Progetto GCP : ${PROJECT_ID}"
echo "🌍  Region       : ${REGION}"
echo "🖼️   Image        : ${IMAGE}"
echo ""

# ── Build immagine Docker ─────────────────────────
echo "📦  Build immagine Docker via Cloud Build..."
gcloud builds submit --tag "${IMAGE}" .

# ── Deploy su Cloud Run ───────────────────────────
echo ""
echo "🚀  Deploy su Cloud Run..."
gcloud run deploy "${SERVICE_NAME}" \
    --image "${IMAGE}" \
    --platform managed \
    --region "${REGION}" \
    --allow-unauthenticated \
    --memory 256Mi \
    --cpu 1 \
    --min-instances 0 \
    --max-instances 3 \
    --timeout 60

echo ""
echo "✅  Deploy completato!"
SERVICE_URL=$(gcloud run services describe "${SERVICE_NAME}" \
    --platform managed --region "${REGION}" \
    --format "value(status.url)")
echo "🌐  URL: ${SERVICE_URL}"
echo ""
