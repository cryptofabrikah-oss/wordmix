# 🔒 Configuração Segura do Firebase - WordMix

## 📋 Visão Geral

Este projeto agora utiliza um **sistema de configuração segura** que separa dados sensíveis do código commitado, seguindo as melhores práticas de segurança.

## 🚀 Como Configurar

### 1. **Copie o Template**
```bash
# Copie o arquivo template para criar sua configuração local
copy .env.local.template .env.local
```

### 2. **Preencha suas Credenciais**
Abra o arquivo `.env.local` e substitua os valores pelas suas credenciais reais do Firebase:

```env
FIREBASE_API_KEY=sua_api_key_aqui
FIREBASE_AUTH_DOMAIN=seu-projeto.firebaseapp.com
FIREBASE_DATABASE_URL=https://seu-projeto-default-rtdb.firebaseio.com/
FIREBASE_PROJECT_ID=seu-projeto-id
FIREBASE_STORAGE_BUCKET=seu-projeto.appspot.com
FIREBASE_MESSAGING_SENDER_ID=123456789
FIREBASE_APP_ID=1:123456789:web:abcdef123456
```

### 3. **Obter Credenciais do Firebase**
1. Acesse [Firebase Console](https://console.firebase.google.com/)
2. Selecione seu projeto
3. Vá em **Configurações do projeto** > **Geral**
4. Role até **"Seus apps"** e clique em **"Configuração"**
5. Copie os valores para o arquivo `.env.local`

## 🛡️ Segurança Implementada

### ✅ **Arquivos Protegidos (não commitados)**
- `.env.local` - Suas credenciais reais
- `firebase_config_secure.gd` - Lógica de leitura segura
- `firebase_config_template.gd` - Template original

### ✅ **Arquivos Commitados (seguros)**
- `.env.local.template` - Template sem dados sensíveis
- `firebase_config.gd` - Apenas referência ao sistema seguro
- `SETUP_SEGURO.md` - Esta documentação

## 🔄 Como Funciona

1. **`firebase_config.gd`** - Ponto de entrada principal (commitado)
2. **`firebase_config_secure.gd`** - Lê o arquivo `.env.local` (não commitado)
3. **`.env.local`** - Contém suas credenciais reais (não commitado)
4. **`.env.local.template`** - Template para novos desenvolvedores (commitado)

## 🚨 Importante

- **NUNCA** commite o arquivo `.env.local`
- **SEMPRE** use o template para novos ambientes
- **VERIFIQUE** se o `.gitignore` está protegendo os arquivos corretos
- **COMPARTILHE** apenas o template, nunca as credenciais reais

## 🔧 Fallback de Segurança

Se o arquivo `.env.local` não for encontrado, o sistema usa uma configuração de fallback temporária e exibe avisos no console. **Remova o fallback em produção!**

## 📝 Para Novos Desenvolvedores

1. Clone o repositório
2. Copie `.env.local.template` para `.env.local`
3. Preencha com suas credenciais do Firebase
4. Execute o projeto normalmente

## ✨ Benefícios

- 🔒 **Credenciais seguras** - Nunca commitadas
- 🔄 **Fácil setup** - Template pronto para usar
- 🛡️ **Múltiplas camadas** - Proteção no .gitignore
- 📚 **Documentado** - Processo claro e simples
- 🚀 **Escalável** - Funciona para qualquer ambiente