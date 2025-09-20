# 🔥 Firebase Setup Simplificado - SEM Service Account

## ✅ **Boa Notícia: Seu jogo NÃO precisa de Service Account!**

Para jogos mobile como o seu, você só precisa da **configuração client-side** do Firebase. Service accounts são apenas para aplicações server-side.

## 🎯 **O que você REALMENTE precisa**

### 1. **Configuração Web do Firebase**
```
✅ API Key
✅ Auth Domain  
✅ Database URL
✅ Project ID
✅ Storage Bucket
✅ Messaging Sender ID
✅ App ID
```

### 2. **Funcionalidades que funcionam SEM service account:**
- ✅ **Authentication** (email/password, anônimo, OAuth)
- ✅ **Realtime Database** (com regras de segurança)
- ✅ **Cloud Storage** (com regras de segurança)
- ✅ **Analytics**
- ✅ **Remote Config**
- ✅ **Cloud Messaging**

## 🚀 **Setup Rápido (5 minutos)**

### Passo 1: Obter Configurações do Firebase
1. Acesse [Firebase Console](https://console.firebase.google.com/)
2. Selecione seu projeto `cinco-words`
3. Vá em **⚙️ Configurações do Projeto**
4. Role até **"Seus apps"**
5. Clique em **"Configuração"** no app web
6. Copie as configurações

### Passo 2: Configurar Variáveis de Ambiente
```bash
# Copie o template
cp .env.template .env

# Edite o arquivo .env com suas configurações reais
```

### Passo 3: Usar no Código
```gdscript
# O firebase_config_template.gd já está pronto!
var config = FirebaseConfigTemplate.new()
var firebase_config = config.get_firebase_config()
```

## 🔒 **Segurança sem Service Account**

### **Regras do Realtime Database:**
```json
{
  "rules": {
    "users": {
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "$uid === auth.uid"
      }
    },
    "public": {
      ".read": true,
      ".write": "auth != null"
    }
  }
}
```

### **Regras do Storage:**
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## 🎮 **Para Jogos Mobile: Client-Side é Perfeito!**

Seu jogo mobile funciona 100% com:
1. **Autenticação client-side** (usuários fazem login no app)
2. **Regras de segurança** (protegem os dados)
3. **Tokens de usuário** (gerados automaticamente)

## 🔧 **Arquivos Atualizados**

- ✅ `firebase_config_template.gd` - Removido service account
- ✅ `.env.template` - Simplificado para client-side
- ✅ `.gitignore` - Protege credenciais
- ✅ Este guia - Setup simplificado
