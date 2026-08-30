# Nexus DataOps — Kubernetes

Manifests Kubernetes da plataforma Nexus para laboratório local em K3D e produção no
Oracle Kubernetes Engine (OKE). Este guia descreve o setup, a validação e a ordem de
deploy do motor de campanhas, gateway de mensageria e integração por tenant da
`nexus-api`.

## Pré-requisitos

- Docker 24+;
- `k3d`, somente para o ambiente local;
- `kubectl` compatível com o cluster;
- Kustomize 5 (`/usr/bin/kustomize` nos exemplos);
- acesso ao GHCR no OKE e kubeconfig autorizado;
- `cert-manager`, Gateway API e NGINX Gateway Fabric instalados antes dos HTTPRoutes.

Confira as versões e o contexto antes de qualquer alteração:

```bash
docker version
k3d version
kubectl version --client
/usr/bin/kustomize version
kubectl config current-context
```

O passo a passo de criação do cluster local está em [k3d.md](k3d.md). O nome esperado
pelos exemplos é `k8s-dataops`.

## Organização dos manifests

```text
bases/                                  recursos reutilizáveis, sem dados de ambiente
projetos/local/nexus-campaign-api/      API + worker + MySQL + Redis no K3D
projetos/local/nexus-campaign-webapp/   frontend do motor no K3D
projetos/local/nexus-msg/               gateway API/worker + painel no K3D
projetos/local/<tenant>/nexus-api/      API de um tenant no K3D (ex.: teste)
projetos/oke/nexus-campaign-api/        API + worker do motor no OKE
projetos/oke/nexus-campaign-webapp/     frontend do motor no OKE
projetos/oke/nexus-msg/                 gateway API/worker + painel no OKE
projetos/oke/<tenant>/nexus-api/        API de cada tenant no OKE
projetos/{local,oke}/nexus-gateway/     Gateway e certificados compartilhados
```

Sempre altere a base para comportamento comum e o overlay para URLs, imagens,
réplicas, recursos e Secrets específicos do ambiente.

## ConfigMap e Secret

Dados não sensíveis pertencem ao ConfigMap; credenciais pertencem ao Secret ou, de
preferência, a um gerenciador externo de segredos.

| Componente | ConfigMap | Secret |
|---|---|---|
| `nexus-api` tenant | `NEXUS_CAMPAIGN_ENABLED`, URL, timeout e DDI padrão | `NEXUS_CAMPAIGN_API_KEY` |
| Campaign API | CORS, rate limit, pool, flags e parâmetros do worker | `DATABASE_URL`, `REDIS_URL`, JWT/CI token e segredo HMAC |
| Campaign WebApp | `CAMPAIGN_API_URL` em `env.js` | nenhum; segredo nunca vai ao browser |
| Msg API | App/config IDs públicos, versão Meta, CORS, retry e allowlist | banco, App Secret, verify token, admin key e session secret |
| Msg WebApp | `API_BASE_URL` em `env.js` | nenhum; admin key é informada ao login e não persistida |

Antes de aplicar qualquer overlay:

```bash
rg -n 'REPLACE_|CHANGE_ME|change-me' projetos/local projetos/oke
```

O repositório contém Secrets manifestados para bootstrap e ambientes legados. Trate-os
como comprometidos caso tenham valores reais: rotacione as credenciais e migre para
External Secrets/OCI Vault. Base64 em YAML é codificação, não criptografia.

## Setup e deploy no K3D

### 1. Preparar o cluster

Crie o cluster conforme [k3d.md](k3d.md), instale a infraestrutura base e confirme que
os nós estão prontos:

```bash
kubectl config use-context k3d-k8s-dataops
kubectl get nodes
kubectl apply -k bases/gateway-api/1.5
kubectl apply -k bases/cert-manager/1.19
kubectl apply -k bases/nginx-gateway-fabric/2.4
kubectl apply -k projetos/local/nexus-gateway
```

### 2. Gerar e importar imagens

Execute a partir do diretório que contém os repositórios irmãos:

```bash
docker build -t ghcr.io/synapsehealthtech/nexus-campaign-api:v1.0.0 nexus-campaign-api
docker build -t ghcr.io/synapsehealthtech/nexus-campaign-webapp:v1.0.0 nexus-campaign-webapp
docker build -t nexus-msg-api:v0.1.0 nexus-msg-api
docker build -t nexus-msg-webapp:v0.1.0 nexus-msg-webapp

k3d image import ghcr.io/synapsehealthtech/nexus-campaign-api:v1.0.0 -c k8s-dataops
k3d image import ghcr.io/synapsehealthtech/nexus-campaign-webapp:v1.0.0 -c k8s-dataops
k3d image import nexus-msg-api:v0.1.0 nexus-msg-webapp:v0.1.0 -c k8s-dataops
```

Se mudar uma tag, atualize primeiro o Deployment correspondente. Não reutilize a mesma
tag para conteúdo diferente em testes compartilhados.

### 3. Validar os overlays

```bash
/usr/bin/kustomize build projetos/local/nexus-campaign-api >/dev/null
/usr/bin/kustomize build projetos/local/nexus-campaign-webapp >/dev/null
/usr/bin/kustomize build projetos/local/nexus-msg >/dev/null
/usr/bin/kustomize build projetos/local/teste/nexus-api >/dev/null

kubectl apply --dry-run=client -k projetos/local/nexus-campaign-api
kubectl apply --dry-run=client -k projetos/local/nexus-campaign-webapp
kubectl apply --dry-run=client -k projetos/local/nexus-msg
kubectl apply --dry-run=client -k projetos/local/teste/nexus-api
```

### 4. Aplicar na ordem de dependência

```bash
kubectl apply -k projetos/local/nexus-campaign-api
kubectl rollout status deployment/nexus-campaign-api -n nexus-campaign

kubectl apply -k projetos/local/nexus-campaign-webapp
kubectl rollout status deployment/nexus-campaign-webapp -n nexus-campaign

kubectl apply -k projetos/local/nexus-msg
kubectl rollout status deployment/nexus-msg-api-deployment -n nexus-msg-api
kubectl rollout status deployment/nexus-msg-webapp-deployment -n nexus-msg-webapp

kubectl apply -k projetos/local/teste/nexus-api
kubectl rollout status deployment/nexus-api-deployment -n nexus-api-teste
```

No K3D, o Campaign API cria o schema automaticamente para laboratório. Em ambientes
persistentes, desabilite `AUTO_CREATE_SCHEMA` e execute as migrations explicitamente.

### 5. Habilitar a integração da tenant API

Após o Campaign API ficar pronto:

1. gere um JWT admin em `POST /api/v1/admin/token`, enviando o Secret no header
   `X-Nexus-CI-Token`;
2. crie o tenant em `POST /api/v1/admin/tenants`;
3. salve a API key retornada uma única vez como `NEXUS_CAMPAIGN_API_KEY` no Secret da
   `nexus-api`;
4. mantenha no ConfigMap:

```yaml
NEXUS_CAMPAIGN_ENABLED: "true"
NEXUS_CAMPAIGN_API_URL: "http://nexus-campaign-api-service.nexus-campaign.svc.cluster.local"
NEXUS_CAMPAIGN_TIMEOUT_SECONDS: "15"
NEXUS_CAMPAIGN_DEFAULT_PHONE_COUNTRY_CODE: "55"
```

Reaplique o overlay do tenant e aguarde o rollout. A chave nunca deve aparecer no
ConfigMap, logs ou frontend.

## Validação e deploy no OKE

Deploy no OKE é manual. Não execute `apply` sem janela e aprovação operacional.

### 1. Selecionar e provar o contexto

```bash
export KUBECONFIG=/home/haroldoproenca/.kube/config_oci
kubectl config current-context
kubectl cluster-info
```

Interrompa se o contexto não for o OKE esperado.

### 2. Preparar produção

- publique tags imutáveis GHCR com suporte a `linux/arm64`;
- ajuste as tags dos Deployments;
- substitua todos os placeholders `REPLACE_*`;
- crie/valide `ghcr-secret` nos namespaces que puxam imagens privadas;
- aplique migrations do Campaign API, Msg API e de cada tenant antes dos rollouts;
- valide DNS, certificados, Gateway e CORS;
- crie o tenant do motor e armazene a API key no Secret da tenant API;
- mantenha `NEXUS_CAMPAIGN_ENABLED=false` até a API key e o smoke test estarem prontos.

### 3. Render, dry-run e diff

```bash
/usr/bin/kustomize build projetos/oke/nexus-campaign-api >/dev/null
/usr/bin/kustomize build projetos/oke/nexus-campaign-webapp >/dev/null
/usr/bin/kustomize build projetos/oke/nexus-msg >/dev/null
/usr/bin/kustomize build projetos/oke/<tenant>/nexus-api >/dev/null

kubectl apply --dry-run=client -k projetos/oke/nexus-campaign-api
kubectl apply --dry-run=client -k projetos/oke/nexus-campaign-webapp
kubectl apply --dry-run=client -k projetos/oke/nexus-msg
kubectl apply --dry-run=client -k projetos/oke/<tenant>/nexus-api

kubectl diff -k projetos/oke/nexus-campaign-api
kubectl diff -k projetos/oke/nexus-campaign-webapp
kubectl diff -k projetos/oke/nexus-msg
kubectl diff -k projetos/oke/<tenant>/nexus-api
```

O `kubectl diff` pode retornar código `1` quando há diferenças; revise o conteúdo antes
de continuar.

### 4. Ordem de aplicação

Depois da aprovação:

1. Gateway, certificados e `ReferenceGrant` necessários;
2. migrations de banco;
3. Campaign API/worker e Msg API/worker;
4. Campaign WebApp e Msg WebApp;
5. `nexus-api` do tenant, inicialmente com a integração desabilitada;
6. cadastro/smoke do tenant no motor;
7. ativação de `NEXUS_CAMPAIGN_ENABLED=true` e novo rollout da tenant API.

```bash
kubectl apply -k projetos/oke/nexus-gateway
kubectl apply -k projetos/oke/nexus-campaign-api
kubectl apply -k projetos/oke/nexus-msg
kubectl apply -k projetos/oke/nexus-campaign-webapp
kubectl apply -k projetos/oke/<tenant>/nexus-api
```

## Testes pós-deploy

### Estado e probes

```bash
kubectl get pods -n nexus-prod
kubectl get pods -n nexus-msg-api
kubectl get pods -n nexus-msg-webapp
kubectl get pods -n nexus-api-<tenant>

kubectl rollout status deployment/nexus-campaign-api -n nexus-prod
kubectl rollout status deployment/nexus-campaign-webapp -n nexus-prod
kubectl rollout status deployment/nexus-msg-api-deployment -n nexus-msg-api
kubectl rollout status deployment/nexus-msg-worker-deployment -n nexus-msg-api
kubectl rollout status deployment/nexus-msg-webapp-deployment -n nexus-msg-webapp
kubectl rollout status deployment/nexus-api-deployment -n nexus-api-<tenant>
```

### Smoke funcional

- Campaign API: `/health` responde e `/ready` confirma MySQL;
- Campaign WebApp: `/health` e `/env.js` apontam para a API correta;
- Msg API: `/health`, `/health/ready` e verify do webhook retornam sucesso;
- Msg worker: evento teste sai de `RECEIVED` para `ROUTED`;
- Msg WebApp: login, KPIs, tenants, contas e reprocessamento funcionam;
- tenant API: `/api/v1/healthz` e teste de integração criam uma campanha idempotente;
- CORS, TLS, HTTPRoutes e DNS funcionam a partir de uma rede externa ao cluster.

Consulte logs somente no namespace e Deployment exatos; não copie payloads ou Secrets
para tickets:

```bash
kubectl logs -n nexus-prod deployment/nexus-campaign-api --all-containers --tail=100
kubectl logs -n nexus-msg-api deployment/nexus-msg-api-deployment --tail=100
kubectl logs -n nexus-msg-api deployment/nexus-msg-worker-deployment --tail=100
```

## Rollback

Prefira reverter para uma tag de imagem previamente validada e versionar essa mudança
em Git. Para incidentes imediatos, consulte o histórico e reverta apenas o Deployment
afetado:

```bash
kubectl rollout history deployment/<deployment> -n <namespace>
kubectl rollout undo deployment/<deployment> -n <namespace>
kubectl rollout status deployment/<deployment> -n <namespace>
```

Depois do rollback, registre a tag ativa, valide banco/filas e abra uma correção nos
manifests para que o estado declarado volte a representar o cluster.

## Limitações conhecidas

- o Campaign API ainda precisa de um adaptador outbound real para WhatsApp/e-mail; sem
  ele, o worker preserva a fila e não comprova entrega ao provedor;
- o Campaign WebApp persiste a API key do tenant no browser e não deve ser exposto
  publicamente sem BFF/SSO/OIDC;
- Secrets históricos versionados devem ser rotacionados e removidos em uma iniciativa
  separada com plano de migração, para não quebrar ambientes ativos.

## Referências internas

- [Criação do K3D](k3d.md)
- [Gateway API](bases/gateway-api/1.5)
- [cert-manager](bases/cert-manager/1.19)
- [NGINX Gateway Fabric](bases/nginx-gateway-fabric/2.4)
