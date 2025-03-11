# -------------------------------------------
# Parte 1 - Criação Automatizada de Usuários e Grupos
# -------------------------------------------

# 1. Definindo os grupos a serem criados
$grupos = @("TI", "Comercial", "Financeiro", "Compras", "Producao")

# 2. Criando os grupos
foreach ($grupo in $grupos) {
    # Verificando se o grupo já existe
    if (-not (Get-ADGroup -Filter {Name -eq $grupo})) {
        # Criando o grupo
        New-ADGroup -Name $grupo -GroupScope Global -Path "OU=Grupos,DC=dominio,DC=com"
        Write-Host "Grupo $grupo criado com sucesso."
    } else {
        Write-Host "Grupo $grupo já existe."
    }
}

# 3. Criando os usuários (20 usuários de exemplo)
for ($i = 1; $i -le 20; $i++) {
    $nome = "usuario$i.sobrenome"
    $senha = ConvertTo-SecureString "Senai@134" -AsPlainText -Force

    # Criando o usuário no AD
    New-ADUser -SamAccountName $nome -UserPrincipalName "$nome@dominio.com" `
               -Name $nome -GivenName "Usuario $i" -Surname "Sobrenome" `
               -Path "OU=Usuarios,DC=dominio,DC=com" -AccountPassword $senha `
               -Enabled $true -ChangePasswordAtLogon $true -PassThru
1
    # Atribuindo o usuário ao grupo (distribuição por rodízio)
    $grupo = $grupos[$i % $grupos.Length]
    Add-ADGroupMember -Identity $grupo -Members $nome
    Write-Host "Usuário $nome criado e adicionado ao grupo $grupo."
}

# -------------------------------------------
# Parte 2 - Monitoramento e Limpeza de Contas Inativas
# -------------------------------------------

# 1. Definindo o período de inatividade (em dias)
$periodoInatividade = 10 # Para testes rápidos (ajustar conforme necessário)

# 2. Obtendo contas inativas
$contasInativas = Get-ADUser -Filter {Enabled -eq $true} -Properties LastLogonDate | Where-Object {
    $_.LastLogonDate -lt (Get-Date).AddDays(-$periodoInatividade)
}

# 3. Gerando relatório de contas inativas
$relatorio = $contasInativas | Select-Object Name, SamAccountName, LastLogonDate

# Exibindo relatório
$relatorio | Format-Table -AutoSize

# 4. Desativando as contas inativas
foreach ($conta in $contasInativas) {
    Disable-ADAccount -Identity $conta.SamAccountName
    Write-Host "Conta $($conta.SamAccountName) desativada."
}

# 5. Enviando notificação para o administrador
$administradorEmail = "admin@dominio.com"
Send-MailMessage -To $administradorEmail -From "noreply@dominio.com" `
                 -Subject "Contas Inativas Desativadas" `
                 -Body "As contas inativas foram desativadas. Verifique o relatório gerado." `
                 -SmtpServer "smtp.dominio.com"

# -------------------------------------------
# Parte 3 - Desabilitação de Contas com Base em Lista do RH
# -------------------------------------------

# 1. Carregando a lista de usuários desligados do arquivo CSV
$usuariosDesligados = Import-Csv -Path "C:\Caminho\usuarios_desligados.csv"

# 2. Processando cada usuário da lista
foreach ($usuario in $usuariosDesligados) {
    # Verificando se o usuário existe no AD
    $conta = Get-ADUser -Filter {SamAccountName -eq $usuario.usuário_desligado}

    if ($conta) {
        # Desabilitando a conta
        Disable-ADAccount -Identity $conta.SamAccountName
        Write-Host "Conta $($usuario.usuário_desligado) desabilitada com sucesso."
    } else {
        Write-Host "Usuário $($usuario.usuário_desligado) não encontrado no AD."
    }
}

# 3. Gerando log de desabilitação
$log = $usuariosDesligados | ForEach-Object {
    $conta = Get-ADUser -Filter {SamAccountName -eq $_.usuário_desligado}
    if ($conta) {
        "$($_.usuário_desligado) - Desabilitada"
    } else {
        "$($_.usuário_desligado) - Não encontrada"
    }
}
