#!/usr/bin/env bash
set -Eeuo pipefail

HBA_FILE="${HBA_FILE:-/etc/postgresql/18/main/pg_hba.conf}"
RULE="host    athena          athena_app      172.18.0.0/16           scram-sha-256"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Execute com sudo: sudo $0" >&2
  exit 1
fi

if [[ ! -f "${HBA_FILE}" ]]; then
  echo "pg_hba.conf nao encontrado: ${HBA_FILE}" >&2
  exit 1
fi

if grep -Fq "${RULE}" "${HBA_FILE}"; then
  echo "Regra Athena ja existe em ${HBA_FILE}"
else
  cp "${HBA_FILE}" "${HBA_FILE}.bak-athena-$(date +%Y%m%d%H%M%S)"
  {
    printf '\n# Athena API from K3D/Docker network\n'
    printf '%s\n' "${RULE}"
  } >> "${HBA_FILE}"
  echo "Regra Athena adicionada em ${HBA_FILE}"
fi

PGPASSWORD="${PGPASSWORD:-changeme}" \
  psql -h 127.0.0.1 -p 5432 -U postgres -d postgres -c "SELECT pg_reload_conf();"

PGPASSWORD="${PGPASSWORD:-changeme}" \
  psql -h 127.0.0.1 -p 5432 -U postgres -d postgres \
  -c "SELECT line_number, type, database, user_name, address, netmask, auth_method, error FROM pg_hba_file_rules WHERE database @> ARRAY['athena']::text[] OR user_name @> ARRAY['athena_app']::text[] ORDER BY line_number;"
