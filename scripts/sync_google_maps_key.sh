#!/bin/zsh

set -euo pipefail

function usage() {
    cat <<'EOF'
Usage: scripts/sync_google_maps_key.sh [--project PROJECT_ID] [--secret SECRET_NAME] [--bundle-id BUNDLE_ID] [--output PATH]

Fetch the latest Google Maps API key from Google Secret Manager and write it to
Config/GoogleMaps.xcconfig for local Xcode builds.

The script validates that the secret value resolves to a Google Maps Platform
API key configured for iOS app usage with the expected bundle identifier.

Options:
  --project  GCP project ID. Falls back to GCP_PROJECT_ID, GOOGLE_CLOUD_PROJECT,
             or the active gcloud CLI project.
  --secret   Secret Manager secret name. Defaults to lociq-google-maps-api-key.
  --bundle-id Expected iOS app bundle ID. Defaults to io.chrismahlke.lociq.
  --output   Output xcconfig path. Defaults to Config/GoogleMaps.xcconfig.
  --help     Show this help message.
EOF
}

script_dir="${0:A:h}"
repo_root="${script_dir:h}"
secret_name="lociq-google-maps-api-key"
output_path="${repo_root}/Config/GoogleMaps.xcconfig"
project_id="${GCP_PROJECT_ID:-${GOOGLE_CLOUD_PROJECT:-}}"
bundle_id="io.chrismahlke.lociq"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project)
            project_id="${2:-}"
            shift 2
            ;;
        --secret)
            secret_name="${2:-}"
            shift 2
            ;;
        --bundle-id)
            bundle_id="${2:-}"
            shift 2
            ;;
        --output)
            output_path="${2:-}"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ -z "${project_id}" ]]; then
    if command -v gcloud >/dev/null 2>&1; then
        project_id="$(gcloud config get-value project 2>/dev/null | tr -d '\r' | tr -d '\n')"
    fi
fi

if ! command -v gcloud >/dev/null 2>&1; then
    echo "gcloud CLI is required to sync the Google Maps key." >&2
    exit 1
fi

if [[ -z "${project_id}" ]]; then
    echo "Missing project ID. Pass --project or set GCP_PROJECT_ID." >&2
    exit 1
fi

mkdir -p "$(dirname "${output_path}")"

tmp_file="$(mktemp "${TMPDIR:-/tmp}/google-maps-api-key.XXXXXX")"
trap 'rm -f "${tmp_file}"' EXIT

umask 077
secret_value="$(gcloud secrets versions access latest --secret="${secret_name}" --project="${project_id}")"
secret_value="${secret_value//$'\r'/}"

if [[ -z "${secret_value}" ]]; then
    echo "Secret ${secret_name} in project ${project_id} is empty." >&2
    exit 1
fi

key_resource="$(gcloud services api-keys lookup "${secret_value}" --project="${project_id}" --format='value(name)')"
if [[ -z "${key_resource}" ]]; then
    echo "Secret ${secret_name} does not contain a valid Google Cloud API key." >&2
    exit 1
fi

allowed_bundle_ids="$(gcloud services api-keys describe "${key_resource}" --project="${project_id}" --format='value(restrictions.iosKeyRestrictions.allowedBundleIds)')"
api_targets="$(gcloud services api-keys describe "${key_resource}" --project="${project_id}" --format='value(restrictions.apiTargets[].service)')"

if [[ ",${allowed_bundle_ids}," != *",${bundle_id},"* ]]; then
    echo "API key in secret ${secret_name} is not restricted for iOS bundle ID ${bundle_id}." >&2
    exit 1
fi

if [[ ",${api_targets}," != *",mapsios.googleapis.com,"* ]]; then
    echo "API key in secret ${secret_name} is not authorized for Maps SDK for iOS." >&2
    exit 1
fi

{
    printf '%s\n' '// Local-only Google Maps SDK for iOS key. Do not commit this file.'
    printf '%s\n' "// Synced from Secret Manager secret: ${secret_name}"
    printf 'GOOGLE_MAPS_API_KEY = %s\n' "${secret_value}"
} > "${tmp_file}"

chmod 600 "${tmp_file}"
mv "${tmp_file}" "${output_path}"

echo "Updated ${output_path} from secret ${secret_name} in project ${project_id}."
echo "Validated iOS bundle restriction for ${bundle_id} and Maps SDK for iOS access."
