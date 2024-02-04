## Módulos Pró

Modulos Pro é um conjunto de módulos desenvolvidos para o Painel Web Pro, facilitando a gestão e execução de diversas tarefas automatizadas.

## Recursos

- Gestão e execução automatizada de scripts.
- Interface web para fácil interação com os módulos.
- Suporte a diversas funcionalidades customizáveis.

## Pré-requisitos

O projeiro usa:

 - Go
 - dos2unix
 - supervisor

E tambem usa a biblioteca:

 - github.com/gorilla/mux

## Instalação

Para instalar o Modulos Pro, siga estas etapas:

```bash
sudo wget --quiet -O install.sh https://raw.githubusercontent.com/sshturbo/m-dulo-Go/main/install.sh && sudo chmod +x install.sh && sudo ./install.sh
```

Verificar se está instalado e executado com sucesso só executar o comando.

```bash
sudo supervisorctl status m-dulo
```

Resposta esperando: 

 - m-dulo  RUNNING   pid 26324, uptime 0:29:04


Para poder tá parando os módulos e só executar o comando 

```bash
sudo supervisorctl stop m-dulo && sudo supervisorctl remove m-dulo
```
