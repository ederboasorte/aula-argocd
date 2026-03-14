# ============================================
# STAGE 1: BUILDER
# ============================================
# Usa imagem Alpine (menor tamanho)
FROM node:20-alpine AS builder

# Define diretório de trabalho
WORKDIR /app

# ============================================
# DEPENDÊNCIAS
# ============================================
# Copiar apenas package files (cache layer)
COPY app/package*.json ./

# Instalar dependências de produção
# npm install: instala deps e gera lock file se não existir
# --omit=dev: omite dependências de desenvolvimento
RUN npm install --omit=dev && npm cache clean --force

# ============================================
# CÓDIGO FONTE
# ============================================
# Copiar código da aplicação
COPY app/src/ ./src/

# ============================================
# SEGURANÇA: USUÁRIO NÃO-ROOT
# ============================================
# Criar grupo e usuário nodejs (UID/GID 1001)
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# ============================================
# STAGE 2: RUNTIME (IMAGEM FINAL)
# ============================================
# Nova imagem limpa (sem build artifacts)
FROM node:20-alpine AS runtime

# Define diretório de trabalho
WORKDIR /app

# ============================================
# COPIAR ARTEFATOS DO BUILDER
# ============================================
# Copiar apenas o necessário do stage anterior
# Reduz tamanho da imagem final
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/src ./src

# ============================================
# SEGURANÇA: COPIAR USUÁRIO
# ============================================
# Copiar configuração de usuário do builder
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group

# Mudar para usuário não-root (segurança)
USER nodejs

# ============================================
# CONFIGURAÇÃO DA APLICAÇÃO
# ============================================
# Expor porta da aplicação
EXPOSE 3000

# ============================================
# HEALTH CHECK
# ============================================
# Verifica se a aplicação está saudável
# --interval=30s: verifica a cada 30 segundos
# --timeout=3s: timeout de 3 segundos
# --start-period=5s: aguarda 5s antes do primeiro check
# --retries=3: 3 tentativas antes de marcar como unhealthy
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })"

# ============================================
# METADADOS
# ============================================
# Labels para documentação e rastreabilidade
LABEL maintainer="FIAP DevOps Course" \
      version="1.0.0" \
      description="FIAP Todo API for CI/CD demonstrations" \
      org.opencontainers.image.source="https://github.com/fiap/fiap-dclt-aula03"

# ============================================
# COMANDO DE INICIALIZAÇÃO
# ============================================
# Inicia a aplicação Node.js
CMD ["npm", "start"]
