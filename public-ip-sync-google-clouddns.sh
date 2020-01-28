#!/bin/bash

set -e -u -o pipefail

function error() {
	local parent_lineno="${1:-"<UNKNOWN>"}"
	local message="${2-""}"
	local code="${3:-1}"
	if [[ -n "${message}" ]] ; then
		echo "Error on or near line ${parent_lineno}: ${message}; exiting with status ${code}"
	else
		echo "Error on or near line ${parent_lineno}; exiting with status ${code}"
	fi
	exit "${code}"
}
trap 'error ${LINENO}' ERR

POSITIONAL=()
while [[ $# -gt 0 ]]; do
	key="${1}"

	case "${key}" in
	-c|--gcloud-service-account-key-file)
	GCLOUD_SERVICE_ACCOUNT_KEY_FILE="${2}"
	shift # past argument
	shift # past value
	;;
	-p|--cloudsdk-core-project)
	CLOUDSDK_CORE_PROJECT="${2}"
	shift # past argument
	shift # past value
	;;
	-z|--cloudsdk-compute-zone)
	CLOUDSDK_COMPUTE_ZONE="${2}"
	shift # past argument
	shift # past value
	;;
	-zone|--gcloud-dns-zone-id)
	GCLOUD_DNS_ZONE_ID="${2}"
	shift # past argument
	shift # past value
	;;
	-name|--dns-record-name)
	DNS_RECORD_NAME="${2}"
	shift # past argument
	shift # past value
	;;
	-ttl|--dns-record-ttl)
	DNS_RECORD_TTL="${2}"
	shift # past argument
	shift # past value
	;;
	--debug)
	DEBUG=true
	shift # past argument
	;;
	*)    # unknown option
	POSITIONAL+=("$1") # save it in an array for later
	shift # past argument
	;;
	esac
done
set -- "${POSITIONAL[@]}"

if [[ "${DEBUG:-false}" == "true" ]]; then
	echo "DEBUG output enabled."
	set -x
fi

# TODO Check if variables have been set and emit readable error message.
GCLOUD_SERVICE_ACCOUNT_KEY_FILE="${GCLOUD_SERVICE_ACCOUNT_KEY_FILE:-"/etc/my-dyndns/gcloud-service-account-key.json"}"
CLOUDSDK_CORE_PROJECT="${CLOUDSDK_CORE_PROJECT}"
CLOUDSDK_COMPUTE_ZONE="${CLOUDSDK_COMPUTE_ZONE}"
GCLOUD_DNS_ZONE_ID="${GCLOUD_DNS_ZONE_ID}"
DND_RECORD_NAME="${DNS_RECORD_NAME}"
DNS_RECORD_TTL="${DNS_RECORD_TTL:-60}"

gcloud --quiet auth activate-service-account --key-file="${GCLOUD_SERVICE_ACCOUNT_KEY_FILE}"

function reconcile() {
	public_ipv4_address="$(curl -4 -s https://ifconfig.me/ip)"
	if [[ ! "$?" -eq 0 ]] || [[ -z "{public_ipv4_address}" ]]; then
		echo "Unable to determine public IPv4 address."
		exit 1
	fi

	resolved_a_record="$(dig +short A "${DNS_RECORD_NAME}" | tail -n1 | grep '^[0-9][.0-9][.0-9][.0-9]' || echo "")"
	if [[ -z "${resolved_a_record}" ]]; then
		echo "Public IP address could not be resolved from desired DNS record name."
		echo "Maybe it has never been set? Assuming that it will be set for the first time."
	elif [[ ! -z "${resolved_a_record}" ]] && [[ "${public_ipv4_address}" == "${resolved_a_record}" ]]; then
		echo "Public IPv4 address \"${public_ipv4_address}\" hasn't changed. Exiting..."
		exit 0
	fi

	# Start new transaction.
	gcloud dns record-sets transaction start --zone="${GCLOUD_DNS_ZONE_ID}"

	# Remove existing record IF it exists.
	existing_dns_record=($(gcloud dns record-sets list --zone="${GCLOUD_DNS_ZONE_ID}" --project="${CLOUDSDK_CORE_PROJECT}" --filter="type=A AND name=${DND_RECORD_NAME}" --format="table[no-heading](name,type,ttl,rrdatas)"))
	if [[ ! -z "${existing_dns_record[@]}" ]]; then
		existing_dns_record_name="${existing_dns_record[0]}"
		existing_dns_record_type="${existing_dns_record[1]}"
		existing_dns_record_ttl="${existing_dns_record[2]}"
		existing_dns_record_rrdatas="${existing_dns_record[3]}"
		echo "Removing existing DNS record \"name=${existing_dns_record_name} type=${existing_dns_record_type} ttl=${existing_dns_record_ttl} rrdatas=${existing_dns_record_rrdatas}\"..."
		gcloud dns record-sets transaction remove --zone="${GCLOUD_DNS_ZONE_ID}" --name="${existing_dns_record_name}" --type="${existing_dns_record_type}" --ttl="${existing_dns_record_ttl}" "${existing_dns_record_rrdatas}"
	fi

	echo "Setting new DNS record \"name=${DND_RECORD_NAME} type=A ttl=${DNS_RECORD_TTL} rrdatas=${public_ipv4_address}\"..."
	gcloud dns record-sets transaction add --zone="${GCLOUD_DNS_ZONE_ID}" --name="${DND_RECORD_NAME}" --ttl="${DNS_RECORD_TTL}" --type="A" "${public_ipv4_address}"

	# Commit transaction.
	gcloud dns record-sets transaction execute --zone="${GCLOUD_DNS_ZONE_ID}"
}

reconcile
