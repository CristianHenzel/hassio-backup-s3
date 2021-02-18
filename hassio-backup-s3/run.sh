#!/usr/bin/env bashio

ACCESSKEY=$(bashio::config 's3_accesskey')
SECRETKEY=$(bashio::config 's3_secretkey')
BUCKET=$(bashio::config 's3_bucket')
ENDPOINT=$(bashio::config 's3_endpoint')
FLAGS=$(bashio::config 's3_flags')
REGION=$(bashio::config 's3_region')
KEEP_DAYS=$(bashio::config 'backup_keep_days')
RUN_INTERVAL=$(bashio::config 'run_interval')
NOW=$(date -Iseconds)
SNAPSHOTS=$(bashio::api.supervisor "GET" "/snapshots" false ".snapshots[]")

createsnapshot() {
	local SNAPSHOTNAME; SNAPSHOTNAME="full-$(date -I)"
	local CREATE; CREATE="true"
	while read -r line; do
		NAME=$(bashio::jq "${line}" ".name")
		if [ "${NAME}" = "${SNAPSHOTNAME}" ]; then
			CREATE="false"
		fi
	done <<< "${SNAPSHOTS}"

	if [ "${CREATE}" = "true" ]; then
		bashio::log.info "Creating new snapshot"
		name=$(bashio::var.json name "${SNAPSHOTNAME}")
		bashio::api.supervisor "POST" "/snapshots/new/full" "${name}"
	fi
}

cleanup() {
	while read -r line; do
		SLUG=$(bashio::jq "${line}" ".slug")
		NAME=$(bashio::jq "${line}" ".name")
		DATE=$(bashio::jq "${line}" ".date")
		PROTECTED=$(bashio::jq "${line}" ".protected")
		AGE=$(datediff "${NOW}" "${DATE}")
		if [ -z "${NAME}" ]; then
			FULLNAME="${SLUG}"
		else
			FULLNAME="$NAME (${SLUG})"
		fi

		if [ "${AGE}" -gt "${KEEP_DAYS}" ]; then
			# TODO: Don't delete snapshot if it's protected
			bashio::log.info "Deleting snapshot ${FULLNAME} since it is ${AGE} days old"
			bashio::api.supervisor "DELETE" "/snapshots/${SLUG}"
		else
			bashio::log.info "Skipping snapshot ${FULLNAME} because it is only ${AGE} days old"
		fi
	done <<< "${SNAPSHOTS}"
}

datediff() {
	d1=$(date -d "$1" +%s)
	d2=$(date -d "$2" +%s)
	echo $(( (d1 - d2) / 86400 ))
}

init() {
	aws configure set default.s3.signature_version s3v4
	aws configure set aws_access_key_id "${ACCESSKEY}"
	aws configure set aws_secret_access_key "${SECRETKEY}"
	aws configure set region "${REGION}"
}

sync() {
	bashio::log.info "Syncing to S3 bucket"
	aws --endpoint-url "${ENDPOINT}" ${FLAGS} s3 sync /backup/ s3://${BUCKET}/ 2>&1 | grep -v "InsecureRequestWarning" || true
}

while true; do
	init
	createsnapshot
	cleanup
	sync
	sleep "${RUN_INTERVAL}"
done
