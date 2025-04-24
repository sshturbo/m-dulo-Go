#!/bin/bash

# Função para gerar um e-mail aleatório
gerar_email_aleatorio() {
    tamanho=10
    caracteres=($(echo {a..z} {A..Z} {0..9}))
    email_local=""
    for ((i=0; i<tamanho; i++)); do
        index=$(( $RANDOM % ${#caracteres[@]} ))
        email_local+="${caracteres[$index]}"
    done
    echo "${email_local}"
}

# Função para adicionar usuário ao sistema
adicionar_usuario_sistema() {
    username=$1
    password=$2
    dias=$3
    sshlimiter=$4

    # Verificar se o usuário já existe
    if id "$username" &>/dev/null; then
        echo "Usuário '$username' já existe. Nenhuma ação realizada."
        return 0
    fi

    final=$(date "+%Y-%m-%d" -d "+$dias days")
    pass=$(perl -e 'print crypt($ARGV[0], "password")' $password)
    useradd -e "$final" -M -s /bin/false -p "$pass" "$username" 2>/dev/null

    # Registrar no banco de dados
    echo "$username $sshlimiter" >> /root/usuarios.db
    echo "$password" > /etc/SSHPlus/senha/"$username"
}

# Função para adicionar UUID ao config.json
adicionar_usuario_xray() {
    username=$1
    uuid=$2
    config_file="/usr/local/etc/xray/config.json"
    email=$(gerar_email_aleatorio)

    # Verificar se o arquivo existe
    if [ ! -f "$config_file" ]; then
        echo "Erro: Arquivo de configuração não encontrado."
        exit 1
    fi

    # Criar um novo cliente
    novo_cliente="{\"email\": \"$email\",\"id\": \"$uuid\",\"level\": 0}"

    # Fazer backup do arquivo original
    cp "$config_file" "${config_file}.bak"

    # Adicionar o novo cliente ao arquivo de configuração
    if jq ".inbounds[] |= if .protocol == \"vless\" then .settings.clients += [$novo_cliente] else . end" "$config_file" > "${config_file}.tmp"; then
        mv "${config_file}.tmp" "$config_file"
        echo "Usuário adicionado com sucesso ao Xray."
        
        # Registrar informações do usuário
        echo "$uuid | $username | $(date -d "+$dias days" +"%Y-%m-%d")" >> /root/xrayusers.db
        
        # Reiniciar o serviço xray
        systemctl restart xray || service xray restart
        echo "Serviço Xray reiniciado."
        return 0
    else
        echo "Erro ao atualizar o arquivo de configuração."
        rm -f "${config_file}.tmp"
        mv "${config_file}.bak" "$config_file"
        return 1
    fi
}

# Verificar argumentos
if [ $# -lt 4 ]; then
    echo "Erro: Argumentos insuficientes."
    echo "Uso: $0 <username> <password> <dias> <sshlimiter> [uuid]"
    exit 1
fi

# Coletar argumentos
username=$1
password=$2
dias=$3
sshlimiter=$4
uuid=$5

# Se uuid não for passado, cria só o usuário do sistema
if [ -z "$uuid" ]; then
    adicionar_usuario_sistema "$username" "$password" "$dias" "$sshlimiter"
    sistema_status=$?
    if [ $sistema_status -eq 0 ]; then
        echo "Usuário criado com sucesso no sistema!"
        exit 0
    else
        echo "Houve algum erro durante a criação do usuário no sistema."
        exit 1
    fi
else
    # Se uuid for passado, cria usuário do sistema e no Xray
    adicionar_usuario_sistema "$username" "$password" "$dias" "$sshlimiter"
    sistema_status=$?
    adicionar_usuario_xray "$username" "$uuid"
    xray_status=$?
    if [ $sistema_status -eq 0 ] && [ $xray_status -eq 0 ]; then
        echo "Usuário criado com sucesso no sistema e no Xray!"
        exit 0
    else
        echo "Houve algum erro durante a criação do usuário."
        exit 1
    fi
fi
