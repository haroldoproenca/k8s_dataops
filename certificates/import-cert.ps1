# 1. Defina o caminho onde baixou o rootCA.crt (AJUSTE O CAMINHO ABAIXO)
$certPath = "rootCA.crt"

# 2. Verifica se o arquivo existe
if (Test-Path $certPath) {
    try {
        # 3. Importa para a loja "Autoridades de Certificação Raiz Confiáveis" (Root) do Computador Local
        Import-Certificate -FilePath $certPath -CertStoreLocation Cert:\LocalMachine\Root
        
        Write-Host "Sucesso! O certificado foi instalado. Reinicie o navegador (Chrome/Edge)." -ForegroundColor Green
    }
    catch {
        Write-Host "Erro ao instalar. Certifique-se de estar rodando como ADMINISTRADOR." -ForegroundColor Red
        Write-Host $_.Exception.Message
    }
} else {
    Write-Host "Arquivo não encontrado em: $certPath" -ForegroundColor Red
}
