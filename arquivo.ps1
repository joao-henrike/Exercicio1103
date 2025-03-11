# Definindo a configuração do domínio e caminho do arquivo CSV
$dominioControlador = "192.168.52.137"  # IP do controlador de domínio
$dominio = "RhName.com"  # Nome do domínio
$arquivoCSV = "C:\Caminho\Para\usuarios.csv"  # Caminho do arquivo CSV com dados dos usuários

# Carregar os dados do arquivo CSV para um array de usuários
$usuarios = Get-Content $arquivoCSV

# Lista de grupos de departamentos no AD
$grupos = @("Desenvolvimento", "Infraestrutura", "Backup", "Seguranca", "Usuarios", "Producao", "Aplicacoes")

# Criar os usuários e adicioná-los aos grupos
foreach ($linha in $usuarios) {
    # Separar o nome completo e departamento usando o delimitador ";"
    $dados = $linha.Split(';')
    $nomeCompleto = $dados[0]  # Nome completo do usuário
    $departamento = $dados[1]   # Departamento (grupo) do usuário

    # Separar o nome e sobrenome do nome completo usando "_"
    $nome, $sobrenome = $nomeCompleto.Split('_')

    # Criar o usuário no AD com o nome e senha padrão
    $senha = ConvertTo-SecureString "Senai@134" -AsPlainText -Force  # Definir senha do usuário
    New-ADUser -SamAccountName $nomeCompleto -UserPrincipalName "$nomeCompleto@$dominio" `
               -Name "$nome $sobrenome" -GivenName $nome -Surname $sobrenome `
               -Path "CN=Users,DC=RhName,DC=com" -AccountPassword $senha `
               -Enabled $true -ChangePasswordAtLogon $true -Server $dominioControlador  # Criar o usuário no AD

    # Verificar se o departamento existe e adicionar o usuário ao grupo correspondente
    if ($grupos -contains $departamento) {
        Add-ADGroupMember -Identity $departamento -Members $nomeCompleto -Server $dominioControlador  # Adicionar ao grupo
        Write-Host "Usuário $nome $sobrenome criado e adicionado ao grupo $departamento."  # Mensagem de sucesso
    }
}

# Monitoramento de contas inativas - Definindo um período de inatividade em dias (10 dias aqui)
$periodoInatividade = 10  # Ajuste o valor conforme necessário
$contasInativas = Get-ADUser -Filter {Enabled -eq $true} -Properties LastLogonDate -Server $dominioControlador | Where-Object {
    $_.LastLogonDate -lt (Get-Date).AddDays(-$periodoInatividade)  # Filtrando contas que não logaram nos últimos 10 dias
}

# Desativar contas inativas
$contasInativas | ForEach-Object {
    Disable-ADAccount -Identity $_.SamAccountName -Server $dominioControlador  # Desabilitar a conta
    Write-Host "Conta $_.SamAccountName desativada."  # Mensagem de desativação
}

# Enviar notificação por email para o administrador sobre as contas inativas desativadas
Send-MailMessage -To "jb.goncalves2406@gmail.com -From "noreply@RhName.com" `
                 -Subject "Contas Inativas Desativadas" `
                 -Body "As contas inativas foram desativadas." `
                 -SmtpServer "smtp.RhName.com"  # Enviar email para notificar sobre as contas desativadas

# Desabilitar contas de usuários desligados a partir de um arquivo CSV
$usuariosDesligados = Import-Csv -Path "C:\Users\Administrator\Documents.csv"  # Carregar a lista de usuários desligados do CSV
$usuariosDesligados | ForEach-Object {
    # Procurar no AD o usuário com o SamAccountName correspondente
    $conta = Get-ADUser -Filter {SamAccountName -eq $_.usuário_desligado} -Server $dominioControlador
    if ($conta) {
        Disable-ADAccount -Identity $conta.SamAccountName -Server $dominioControlador  # Desabilitar a conta se encontrada
        Write-Host "Conta $_.usuário_desligado desabilitada."  # Mensagem de sucesso
    } else {
        Write-Host "Usuário $_.usuário_desligado não encontrado."  # Mensagem de erro se não encontrado
    }
}
