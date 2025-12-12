# Overleaf (Community Edition) no OpenMediaVault

Este guia documenta a instalação do Overleaf Community Edition em um ambiente Homelab rodando OpenMediaVault (OMV), utilizando uma pasta partilhada em `/overleaf`.

A instalação utiliza uma **imagem Docker personalizada** para incluir o TeXLive completo, suporte à língua portuguesa (hifenização, babel), normas ABNT/IEEE e fontes adicionais.

## 📋 Pré-requisitos

*   **OpenMediaVault** instalado e configurado.
*   **OMV-Extras** e **Docker** instalados.
*   Acesso **SSH** ao servidor.
*   Pasta partilhada criada e acessível em `/overleaf`.

## 📂 Estrutura de Arquivos

Dentro da sua pasta `/overleaf`, a estrutura final será:

```text
/overleaf
├── custom
│   ├── Dockerfile
├── nginx
│   ├── nginx.conf
├── overleaf_data/      (criado automaticamente)
├── mongo_data/         (criado automaticamente)
└── redis_data/         (criado automaticamente)
```

## 1. Configuração dos Arquivos

Crie os arquivos abaixo dentro da pasta `/overleaf`.

### 1.1. `Dockerfile`
Este arquivo cria uma versão do Overleaf com os pacotes LaTeX extras já instalados.

```dockerfile
FROM sharelatex/sharelatex:latest

ENV TEXLIVE_ROOT=/usr/local/texlive/2025
ENV PATH="${TEXLIVE_ROOT}/bin/x86_64-linux:${PATH}"

RUN curl -L https://mirror.ctan.org/systems/texlive/tlnet/update-tlmgr-latest.sh \
      -o /tmp/update-tlmgr-latest.sh && \
    sh /tmp/update-tlmgr-latest.sh

RUN tlmgr update --self --all && \
 tlmgr install \
      lineno pgf-umlsd \
      memoir caption xpatch pdfpages morewrites \
      minted fvextra upquote \
      lm \
      mathtools physics cancel tensor siunitx amsfonts \
      pgf pgfplots xcolor eso-pic wrapfig subfig \
      booktabs multirow colortbl microtype geometry setspace fancyhdr titlesec enumitem csquotes \
      todonotes eurosym acronym pdfcomment bookmark comment float lipsum placeins \
      tools \
      biblatex biber natbib \
      babel-portuguese \
      hyperref cleveref \
      datetime2 tracklang collection-fontsrecommended zref marginnote soulpos \
      biblatex-ieee bigfoot hyphen-portuguese datetime2-english datetime2-portuguese xstring
```

### 1.2. `docker-compose.yml`
Definição dos serviços.

```yaml

services:
  sharelatex:
    build: /overleaf/custom/
    image: overleaf-custom:latest
    container_name: overleaf
    restart: always
    depends_on:
      mongo:
        condition: service_healthy
      redis:
        condition: service_started
    volumes:
      - /overleaf/overleaf_data:/var/lib/overleaf
      - /overleaf/texlive/texmf-local:/usr/local/texlive/texmf-local
    environment:
      OVERLEAF_APP_NAME: Overleaf Community
      OVERLEAF_MONGO_URL: mongodb://mongo/sharelatex
      OVERLEAF_REDIS_HOST: redis
      OVERLEAF_ENABLED_LINKED_FILE_TYPES: 'project_file,project_output_file'
      OVERLEAF_SECURE_COOKIE: 'true'
      OVERLEAF_BEHIND_PROXY: 'true'
      OVERLEAF_SITE_URL: 'https://localhost:8443' 


  mongo:
    image: mongo:8.0
    container_name: overleaf_mongo
    restart: always
    command: "--replSet overleaf"
    volumes:
      - /overleaf/mongo_data:/data/db
      - /overleaf/mongo_init:/docker-entrypoint-initdb.d
    expose:
      - 27017
    healthcheck:
      test: echo 'db.stats().ok' | mongosh localhost:27017/test --quiet
      interval: 10s
      timeout: 10s
      retries: 5

  overleaf-proxy:
    image: nginx:alpine
    container_name: overleaf_proxy
    restart: always
    ports:
      - "8443:443"
    depends_on:
      - sharelatex
    volumes:
      - /overleaf/nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - /overleaf/nginx/certs:/etc/nginx/certs:ro

  redis:
    image: redis:6.2
    container_name: overleaf_redis
    restart: always
    expose:
      - 6379
    volumes:
      - /overleaf/redis_data:/data
```

### 1.3. Configuração do Nginx (`nginx/nginx.conf`)
Crie a pasta `nginx` e o arquivo `nginx.conf`:

```nginx
events {}

http {
  upstream overleaf_upstream {
    server sharelatex:80;
  }

  server {
    listen 443 ssl;

    ssl_certificate     /etc/nginx/certs/overleaf.crt;
    ssl_certificate_key /etc/nginx/certs/overleaf.key;

    location / {
      proxy_pass http://overleaf_upstream;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto https;
    }
  }
}

```


```bash
mkdir -p /overleaf/nginx/certs
openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout /overleaf/nginx/certs/overleaf.key \
  -out /overleaf/nginx/certs/overleaf.crt \
  -days 3650 \
  -subj "/CN=192.168.1.225"
```





## ⚙️ Configuração Pós-Instalação

Após os containers estarem rodando (`docker compose ps`), você deve executar dois comandos obrigatórios **apenas na primeira vez**.

### 1. Inicializar o Replica Set do MongoDB
O Overleaf exige que o Mongo rode como um Replica Set.

```bash
docker exec -it overleaf_mongo mongosh --eval "rs.initiate({_id:'overleaf', members:[{_id:0, host:'mongo:27017'}]})"
```

### 2. Criar o Usuário Administrador
Substitua o e-mail abaixo pelo seu. Será gerado um link para definir a senha.

```bash
docker exec -it overleaf /bin/bash -c "cd /var/www/sharelatex; grunt user:create-admin --email=fulano@gmail.com"
```
*Copie o URL gerado no terminal e cole no navegador para definir sua senha.*

## 🛠️ Manutenção e Dicas

### Instalar novos pacotes manualmente
Se precisar de um pacote que não estava no Dockerfile, você pode instalar sem reconstruir tudo (mas será perdido se recriar o container, o bom é atualizar o Dockerfile):

1.  Entre no container:
    ```bash
    docker exec -it overleaf bash
    ```
2.  Instale o pacote:
    ```bash
    tlmgr install nome-do-pacote
    ```

### Atualizar a imagem
Se você editar o `Dockerfile` para adicionar novos pacotes permanentemente:

```bash
cd /overleaf
docker compose down
docker compose up -d --build
```

### Acessar Logs
Se algo der errado:
```bash
docker logs overleaf -f
```

---
**URL de Acesso:** `https://<IP-DO-SEU-OMV>:8443`