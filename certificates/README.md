# 🔐 Guia de Configuração TLS (Self-Signed) para Kubernetes Ingress

Este documento descreve o processo completo para habilitar HTTPS seguro em serviços Kubernetes locais. O processo cobre desde a criação de uma Autoridade Certificadora (CA) própria até a configuração dos recursos de Ingress e a importação do certificado no Windows para remover avisos de segurança do navegador.

Domínio Alvo: *.k8sdataops.com.br

## 📋 Pré-requisitos

*  OpenSSL: Instalado no ambiente onde os certificados serão gerados (Linux/WSL/Mac).

*  kubectl: Configurado com acesso ao cluster Kubernetes.

*  PowerShell: Com privilégios de Administrador (para a etapa de cliente Windows).

## 🚀 Parte 1: Geração dos Certificados (OpenSSL)

Execute os comandos abaixo em um terminal Bash para gerar os arquivos necessários.

### 1. Criar a Root CA (Autoridade Certificadora)

Isso cria a identidade que assinará seus certificados.

```
# 1. Gera a chave privada e o certificado da CA (válido por 10 anos)
openssl req -x509 -sha256 -days 3650 -nodes -newkey rsa:2048 \
  -subj "/CN=K8sDataOps Root CA/C=BR/L=Sao Paulo" \
  -keyout rootCA.key -out rootCA.crt
```

### 2. Criar a Chave e CSR para o Domínio Wildcard

Gera o pedido de assinatura para o domínio *.k8sdataops.com.br.
```
# 2. Gera a chave privada do domínio e o pedido de assinatura (CSR)
openssl req -new -nodes -newkey rsa:2048 \
  -subj "/CN=*.k8sdataops.com.br/C=BR/L=Sao Paulo" \
  -keyout wildcard.key -out wildcard.csr
```

### 3. Criar Arquivo de Extensão (SAN) e Assinar

Necessário para que navegadores modernos (Chrome/Edge) aceitem o certificado.
```
# 3. Cria arquivo de configuração de extensões (SAN)
cat > v3.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = *.k8sdataops.com.br
DNS.2 = k8sdataops.com.br
EOF

# 4. Assina o certificado usando a Root CA e a configuração acima
openssl x509 -req -in wildcard.csr -CA rootCA.crt -CAkey rootCA.key \
  -CAcreateserial -out wildcard.crt -days 365 -sha256 -extfile v3.ext
```

## ☸️ Parte 2: Configuração no Kubernetes

### 1. Criar o Secret TLS

Armazena a chave e o certificado gerados dentro do cluster.
```
kubectl create secret tls wild-k8sdataops-tls \
  --key wildcard.key \
  --cert wildcard.crt --dry-run=client -o yaml > secret_certificate.yaml
kubectl apply -f secret_certificate.yaml
```

### 2. Aplicar Manifestos de Ingress

Crie ou atualize os arquivos YAML com as configurações abaixo. Observe a adição do bloco tls e a atualização do CORS para https.

langflow-ingress.yaml (Frontend)
```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: langflow-ingress
  annotations:
    # CORS atualizado para HTTPS
    nginx.org/cors-allow-origin: "[https://langflow.k8sdataops.com.br](https://langflow.k8sdataops.com.br)"
    nginx.org/cors-allow-methods: "GET, PUT, POST, DELETE, OPTIONS"
    nginx.org/cors-allow-headers: "DNT,X-CustomHeader,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Authorization"
    # Redirecionamento forçado para HTTPS
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - langflow.k8sdataops.com.br
      secretName: wild-k8sdataops-tls
  rules:
    - host: langflow.k8sdataops.com.br
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: langflow-service
                port:
                  number: 8080
```

langflowapi-ingress.yaml (Backend)
```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: langflowapi-ingress
  annotations:
    # CORS atualizado para HTTPS
    nginx.org/cors-allow-origin: "[https://langflow.k8sdataops.com.br](https://langflow.k8sdataops.com.br)"
    nginx.org/cors-allow-methods: "GET, PUT, POST, DELETE, OPTIONS"
    nginx.org/cors-allow-headers: "DNT,X-CustomHeader,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Authorization"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - langflowapi.k8sdataops.com.br
      secretName: wild-k8sdataops-tls
  rules:
    - host: langflowapi.k8sdataops.com.br
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: langflow-service-backend
                port:
                  number: 7860
```

Aplique com:
```
kubectl apply -f langflow-ingress.yaml -f langflowapi-ingress.yaml
```
## 💻 Parte 3: Confiar no Certificado (Windows Client)

Para que o navegador exiba o cadeado de segurança e não mostre erros, você deve importar o certificado raiz (rootCA.crt) na máquina que acessará o sistema.

1. Copie o arquivo rootCA.crt gerado na Parte 1 para sua máquina Windows.

2. Abra o PowerShell como Administrador.

3. Execute o script abaixo (lembre-se de ajustar o caminho do arquivo):

```
# ==========================================
# SCRIPT DE IMPORTAÇÃO DE CERTIFICADO RAIZ
# ==========================================

# 1. Defina o caminho onde baixou o rootCA.crt (AJUSTE AQUI)
$certPath = "rootCA.crt"

# 2. Execução da importação
if (Test-Path $certPath) {
    try {
        # Importa para a loja "Autoridades de Certificação Raiz Confiáveis" da Máquina Local
        Import-Certificate -FilePath $certPath -CertStoreLocation Cert:\LocalMachine\Root
        
        Write-Host "✅ SUCESSO! O certificado foi instalado." -ForegroundColor Green
        Write-Host "Reinicie seu navegador (Chrome/Edge/Opera) para testar." -ForegroundColor Gray
    }
    catch {
        Write-Host "❌ ERRO: Falha na instalação." -ForegroundColor Red
        Write-Host "Certifique-se de estar rodando o PowerShell como ADMINISTRADOR." -ForegroundColor Yellow
        Write-Host $_.Exception.Message
    }
} else {
    Write-Host "❌ ARQUIVO NÃO ENCONTRADO: $certPath" -ForegroundColor Red
}
```

## 📝 Notas Finais e Troubleshooting

*  Firefox: O Mozilla Firefox não usa o armazenamento de certificados do Windows por padrão. Para confiar no certificado no Firefox:

1. Vá em Configurações > Privacidade e Segurança.

2. Role até Certificados e clique em Ver Certificados.

3. Na aba Autoridades, clique em Importar....

4. Selecione o rootCA.crt e marque a opção "Confiar nesta CA para identificar sites".

*  DNS: Certifique-se de que o seu arquivo hosts (C:\Windows\System32\drivers\etc\hosts) aponta langflow.k8sdataops.com.br para o IP do seu Ingress Controller.

*  Erro de Autoridade Inválida: Se mesmo após importar o erro persistir, verifique se você importou o rootCA.crt (o certificado da autoridade) e não o wildcard.crt (o certificado do domínio). O navegador precisa confiar na Autoridade.
