# 🔥 Configuração Firebase - Wordmix

Este documento contém todas as instruções necessárias para configurar o Firebase no projeto Wordmix e preparar a exportação para dispositivos móveis.

## 📋 Pré-requisitos

- Godot 4.x instalado
- Conta Google/Firebase ativa
- Plugin Firebase para Godot 4
- Android Studio (para exportação Android)
- Xcode (para exportação iOS - apenas macOS)

## 🚀 Configuração Inicial do Firebase

### 1. Criar Projeto Firebase

1. Acesse [Firebase Console](https://console.firebase.google.com/)
2. Clique em "Adicionar projeto"
3. Nome do projeto: `wordmix-game`
4. Ative Google Analytics (recomendado)
5. Selecione conta do Analytics
6. Clique em "Criar projeto"

### 2. Configurar Authentication

1. No console Firebase, vá para **Authentication**
2. Clique em "Começar"
3. Na aba **Sign-in method**, ative:
   - **Anônimo** (para jogadores sem conta)
   - **Google** (opcional, para login social)
4. Salve as configurações

### 3. Configurar Realtime Database

1. Vá para **Realtime Database**
2. Clique em "Criar banco de dados"
3. Selecione localização (us-central1 recomendado)
4. Inicie em **modo de teste** (temporário)
5. Configure as regras de segurança:

```json
{
  "rules": {
    "players": {
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "$uid === auth.uid"
      }
    },
    "rankings": {
      ".read": true,
      ".write": "auth != null"
    }
  }
}
```

### 4. Adicionar Apps ao Projeto

#### Para Android:
1. Clique em "Adicionar app" → Android
2. Package name: `com.seunome.wordmix`
3. App nickname: `Wordmix Android`
4. Baixe o arquivo `google-services.json`
5. Coloque o arquivo na pasta raiz do projeto Godot

#### Para iOS:
1. Clique em "Adicionar app" → iOS
2. Bundle ID: `com.seunome.wordmix`
3. App nickname: `Wordmix iOS`
4. Baixe o arquivo `GoogleService-Info.plist`
5. Coloque o arquivo na pasta raiz do projeto Godot

## 🔧 Configuração no Godot

### 1. Instalar Plugin Firebase

1. Baixe o plugin Firebase para Godot 4 do [GitHub oficial](https://github.com/GodotNuts/GodotFirebase)
2. Extraia na pasta `addons/` do projeto
3. Ative o plugin em **Project Settings → Plugins**

### 2. Configurar Project Settings

Vá para **Project Settings** e configure:

#### Application:
- **Config/Name**: Wordmix
- **Config/Description**: Jogo de palavras com sincronização Firebase
- **Run/Main Scene**: `scenes/Main.tscn`

#### Firebase:
- **Config/Domain Url**: `https://wordmix-game-default-rtdb.firebaseio.com/`
- **Config/Web Api Key**: (copie da configuração web do Firebase)
- **Config/Storage Bucket**: `wordmix-game.appspot.com`

### 3. Configurar Autoloads

Em **Project Settings → AutoLoad**, adicione:
- **Global**: `scripts/Global.gd`
- **FirebaseAuth**: `addons/firebase/auth/firebase_auth.gd`
- **FirebaseDatabase**: `addons/firebase/database/firebase_database.gd`

## 📱 Configuração para Exportação

### Android

#### 1. Configurar Android Build Template

1. Vá para **Project Settings → Export**
2. Adicione preset "Android"
3. Em **Options**:
   - **Package/Unique Name**: `com.seunome.wordmix`
   - **Package/Name**: `Wordmix`
   - **Package/Signed**: ✅ (para release)

#### 2. Permissões Necessárias

Adicione as seguintes permissões no arquivo `android/build/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

#### 3. Configurar Gradle

No arquivo `android/build/build.gradle`, adicione:

```gradle
dependencies {
    implementation 'com.google.firebase:firebase-auth:21.0.1'
    implementation 'com.google.firebase:firebase-database:20.0.3'
    implementation 'com.google.firebase:firebase-analytics:20.0.0'
}

apply plugin: 'com.google.gms.google-services'
```

### iOS

#### 1. Configurar iOS Export

1. Adicione preset "iOS"
2. Configure:
   - **Application/Bundle Identifier**: `com.seunome.wordmix`
   - **Application/Name**: `Wordmix`
   - **Required Device Capabilities**: `armv7`, `arm64`

#### 2. Configurar Info.plist

Adicione as seguintes entradas:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>REVERSED_CLIENT_ID</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>YOUR_REVERSED_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

## 🧪 Testes e Validação

### 1. Testar Conexão Firebase

Execute o script `firebase_test_connection.gd`:

```gdscript
# No console do Godot
var test = preload("res://scripts/firebase_test_connection.gd").new()
test.run_all_tests()
```

### 2. Executar Suite de Testes

```gdscript
# Teste completo do jogo
var test_suite = preload("res://scripts/GameTestSuite.gd").new()
test_suite.run_all_tests()
```

### 3. Validar Dados

```gdscript
# Validar integridade dos dados
Global.validate_and_fix_data()
```

## 🚀 Deploy e Publicação

### 1. Build de Produção

#### Android:
```bash
# Gerar APK de release
godot --export "Android" wordmix.apk
```

#### iOS:
```bash
# Gerar projeto Xcode
godot --export "iOS" wordmix_ios/
```

### 2. Configurar Firebase para Produção

1. No Firebase Console, vá para **Realtime Database**
2. Altere as regras para produção:

```json
{
  "rules": {
    "players": {
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "$uid === auth.uid && 
                   newData.hasChildren(['name', 'points', 'gold', 'crystal']) &&
                   newData.child('points').isNumber() &&
                   newData.child('gold').isNumber() &&
                   newData.child('crystal').isNumber()"
      }
    },
    "rankings": {
      ".read": true,
      ".write": "auth != null && 
                 newData.hasChildren(['player_id', 'name', 'points']) &&
                 newData.child('points').isNumber()"
    }
  }
}
```

### 3. Monitoramento

Configure alertas no Firebase Console:
- **Authentication**: Monitor de novos usuários
- **Database**: Monitor de uso e performance
- **Crashlytics**: Relatórios de erro (recomendado)

## 🔒 Segurança

### Boas Práticas:

1. **Nunca** commite arquivos de configuração Firebase no Git
2. Use variáveis de ambiente para chaves sensíveis
3. Configure regras de segurança restritivas
4. Monitore uso e custos regularmente
5. Implemente rate limiting para APIs

### Arquivos a Ignorar (.gitignore):

```
# Firebase
google-services.json
GoogleService-Info.plist
firebase-debug.log
.firebase/

# Godot
.import/
export.cfg
export_presets.cfg
```

## 📊 Monitoramento e Analytics

### Métricas Importantes:

- **DAU/MAU**: Usuários ativos diários/mensais
- **Retenção**: Taxa de retorno dos jogadores
- **Progressão**: Níveis completados
- **Monetização**: Compras no jogo (se aplicável)

### Configurar Events Customizados:

```gdscript
# Exemplo de tracking de eventos
func track_level_completed(level: int, score: int):
    Firebase.Analytics.log_event("level_completed", {
        "level": level,
        "score": score,
        "character": Global.selected_avatar
    })
```

## 🆘 Troubleshooting

### Problemas Comuns:

1. **Erro de conexão**: Verifique internet e configuração de domínio
2. **Autenticação falha**: Confirme configuração do Authentication
3. **Dados não sincronizam**: Verifique regras do Database
4. **Build falha**: Confirme dependências e permissões

### Logs Úteis:

```gdscript
# Ativar logs detalhados
Global.debug_mode = true
Firebase.Auth.connect("login_succeeded", self, "_on_login_success")
Firebase.Auth.connect("login_failed", self, "_on_login_failed")
```

## 📞 Suporte

- **Documentação Firebase**: https://firebase.google.com/docs
- **Plugin Godot**: https://github.com/GodotNuts/GodotFirebase
- **Comunidade Godot**: https://godotengine.org/community

---

**Última atualização**: Janeiro 2025
**Versão do documento**: 1.0
**Compatibilidade**: Godot 4.x, Firebase SDK 9.x