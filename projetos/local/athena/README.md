# Athena Local K3D

Manifests locais da solucao Athena.

## Componentes

- `athena-api`: FastAPI Athena, sem banco embarcado.
- `athena-minio`: object storage S3-compatible local para fotos, anexos e artefatos.
- `athena-webapp`: React/Vite servido por NGINX.

## Banco metadata/relacional

O Postgres metadata/relacional da Athena roda fora do cluster, na maquina local
Ubuntu, escutando na porta `5432`. Os pods K3D acessam esse Postgres por:

```text
host.k3d.internal:5432
```

O secret local `athena-api/secret.yaml` aponta para:

```text
postgresql+asyncpg://athena_app:athena@host.k3d.internal:5432/athena
```

Antes de aplicar os manifests, garanta no Postgres local:

- database `athena`;
- role `athena_app`;
- extensao `pgcrypto`;
- permissoes de schema/tabelas para `athena_app`.

Como os pods do K3D chegam ao Postgres local pela rede Docker/K3D, o
`pg_hba.conf` do Postgres no Ubuntu precisa permitir o usuario da aplicacao:

```text
host    athena          athena_app      172.18.0.0/16           scram-sha-256
```

No Postgres 18 local deste ambiente, o arquivo ativo e:

```text
/etc/postgresql/18/main/pg_hba.conf
```

Depois de incluir a regra, recarregue:

```bash
PGPASSWORD=changeme psql -h 127.0.0.1 -p 5432 -U postgres -d postgres -c "SELECT pg_reload_conf();"
```

A inicializacao de tabelas, RLS e seeds fica no Job `athena-db-init`, que executa
`python -m scripts.init_db` usando a imagem da API.

## Vetorizacao e harness

Este pacote nao sobe a camada vetorial/agentica do harness. A orquestracao,
vetorizacao e agentes ficam nos manifests e servicos do AgenticOps/harness.

## Object Storage

No K3D, a API usa MinIO interno:

```text
ATHENA_STORAGE_BACKEND=minio
ATHENA_STORAGE_ENDPOINT=http://athena-minio-service:9000
ATHENA_STORAGE_BUCKET=athena
```

As fotos enviadas pelo formulario sao persistidas como URIs `s3://athena/...` no
banco relacional. Em OKE, mantenha o mesmo contrato e substitua endpoint,
credenciais e bucket por Object Storage gerenciado/OCI S3-compatible.

## Hosts locais

- Webapp: `https://athena.tech.nexusplatform.com.br`
- API: `https://athena-api.tech.nexusplatform.com.br`

## Validacao

```bash
kustomize build /home/haroldoproenca/git/k8s_dataops/projetos/local/athena
rg -n "requests:|limits:" /home/haroldoproenca/git/k8s_dataops/projetos/local/athena
```

O segundo comando nao deve retornar nada no ambiente local.

## Aplicacao no K3D

```bash
export KUBECONFIG=/home/haroldoproenca/.kube/config_k8sdataops
kubectl config current-context
kubectl apply -k /home/haroldoproenca/git/k8s_dataops/projetos/local/athena
kubectl get pods -n athena-api
kubectl get pods -n athena-webapp
```
