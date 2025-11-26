# ⛓️ Deploy do Langflow no Kubernetes

Este documento orienta o processo de configuração de DNS local, instalação de certificados e deploy da aplicação **Langflow (v1.6.9)** em um cluster Kubernetes utilizando Kustomize.

## 📋 Pré-requisitos

* Cluster Kubernetes ativo.
* `kubectl` instalado e configurado.
* Permissões de administrador na máquina local (para edição de arquivo hosts).

---

## 1. Configuração de DNS Local

Para acessar a aplicação via URL amigável, é necessário apontar os endereços locais no arquivo de `hosts` do seu sistema operacional.

### 🪟 Windows
Edite o arquivo `C:\Windows\System32\drivers\etc\hosts` (como Administrador) e adicione:

```text
127.0.0.1   langflow.k8sdataops.com.br
127.0.0.1   langflowapi.k8sdataops.com.br
```

### 🪟 macOS / Linux
Edite o arquivo `/etc/hosts` (usando sudo) e adicione:

```text
127.0.0.1   langflow.k8sdataops.com.br
127.0.0.1   langflowapi.k8sdataops.com.br
```


## 2. Configuração de Segurança (TLS)
Para garantir que o navegador aceite a conexão segura (HTTPS) localmente:

1. Siga o [Guia de Configuração TLS (Self-Signed) para Kubernetes Ingress](../../certificates/README.md).

2. Importe os certificados gerados tanto no Sistema Operacional quanto no Navegador.

## 3. Instalação (Deploy)
Execute o comando abaixo para aplicar os manifestos utilizando o Kustomize:

```bash
kubectl apply -k ../langflow/1.6.9/
```

✅ Verificação do Status
Aguarde alguns instantes e verifique se os pods estão com o status Running:

```bash
kubectl get pods -n langflow # Ajuste o namespace se necessário
```

## 4. Acesso à Aplicação
Após os pods estarem ativos e o DNS configurado, acesse:

*  Frontend (UI): https://langflow.k8sdataops.com.br

*  API: https://langflowapi.k8sdataops.com.br

## 5. Remoção (Undeploy)
Caso precise remover todos os recursos criados por este deploy:

```bash
kubectl delete -k ../langflow/1.6.9/
```
