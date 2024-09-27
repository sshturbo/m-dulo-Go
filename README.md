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

E tambem usa a biblioteca:

 - github.com/gorilla/mux

## Instalação

Para instalar o Modulos Pro, siga estas etapas:

```bash
sudo wget -qO- https://raw.githubusercontent.com/sshturbo/m-dulo-Go/main/install.sh | sudo bash
```

Verificar se está instalado e executado com sucesso só executar o comando.

```bash
sudo systemctl status m-dulo.service
```


Para poder tá parando os módulos e só executar o comando.

```bash
sudo systemctl stop m-dulo.service
```

```bash
sudo systemctl disable m-dulo.service
```

```bash
sudo systemctl daemon-reload
```
 

Para poder ta iniciando os módulos e so executar o comando.

```bash
sudo systemctl enable m-dulo.service
```
```bash
sudo systemctl start m-dulo.service
```