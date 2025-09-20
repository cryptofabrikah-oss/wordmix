# 📱 Guia de Exportação Móvel - Wordmix

Este documento contém instruções detalhadas para exportar o jogo Wordmix para dispositivos Android e iOS.

## 🎯 Visão Geral

O Wordmix é um jogo desenvolvido em Godot 4 com integração Firebase, otimizado para dispositivos móveis com suporte a:
- Sincronização online/offline
- Múltiplas resoluções de tela
- Controles touch otimizados
- Persistência de dados local

## 📋 Pré-requisitos

### Ferramentas Necessárias:
- **Godot 4.2+** com templates de exportação
- **Android Studio** (para Android)
- **Xcode** (para iOS - apenas macOS)
- **Java JDK 11+**
- **Android SDK** (API 33+)

### Arquivos de Configuração:
- `google-services.json` (Android)
- `GoogleService-Info.plist` (iOS)
- Certificados de assinatura

## 🤖 Exportação Android

### 1. Configurar Android SDK

1. Instale Android Studio
2. Configure SDK Manager:
   - **Android SDK Platform 33** (API 33)
   - **Android SDK Build-Tools 33.0.0**
   - **Android SDK Command-line Tools**
3. Configure variáveis de ambiente:
   ```bash
   ANDROID_HOME=C:\Users\%USERNAME%\AppData\Local\Android\Sdk
   JAVA_HOME=C:\Program Files\Java\jdk-11.0.x
   ```

### 2. Configurar Godot para Android

1. Vá para **Editor → Editor Settings**
2. Em **Export → Android**:
   - **Android Sdk Path**: `%ANDROID_HOME%`
   - **Debug Keystore**: Use o padrão ou crie um personalizado
   - **Debug Keystore User**: `androiddebugkey`
   - **Debug Keystore Pass**: `android`

### 3. Criar Preset de Exportação

1. **Project → Export**
2. **Add → Android**
3. Configure as opções:

#### Opções Básicas:
```
Name: Wordmix Android
Runnable: ✅
Dedicated Server: ❌
```

#### Package:
```
Unique Name: com.seunome.wordmix
Name: Wordmix
Signed: ✅ (para release)
```

#### Launcher Icons:
```
Main 192x192: res://icons/icon_192.png
Adaptive Foreground 432x432: res://icons/adaptive_foreground.png
Adaptive Background 432x432: res://icons/adaptive_background.png
```

#### Graphics:
```
OpenGL ES 3.0: ✅
Vulkan: ❌ (para compatibilidade)
```

#### XR Features:
```
XR Mode: Regular
Hand Tracking: None
```

#### Screen:
```
Orientation: Portrait
Support Small: ✅
Support Normal: ✅
Support Large: ✅
Support Xlarge: ✅
```

#### User Data Backup:
```
Allow: ✅
```

#### Command Line:
```
Extra Args On Export: --export-debug
```

### 4. Configurar Permissões

Crie arquivo `android/build/AndroidManifest.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.seunome.wordmix"
    android:versionCode="1"
    android:versionName="1.0">

    <!-- Permissões necessárias -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" 
                     android:maxSdkVersion="28" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" 
                     android:maxSdkVersion="28" />
    <uses-permission android:name="android.permission.VIBRATE" />

    <!-- Características do dispositivo -->
    <uses-feature android:name="android.hardware.touchscreen" 
                  android:required="true" />
    <uses-feature android:name="android.hardware.screen.portrait" 
                  android:required="false" />

    <application
        android:allowBackup="true"
        android:icon="@mipmap/icon"
        android:label="@string/godot_project_name_string"
        android:theme="@style/GodotAppMainTheme"
        android:hardwareAccelerated="true"
        android:requestLegacyExternalStorage="true">

        <!-- Firebase Configuration -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_icon"
            android:resource="@drawable/icon" />
        
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_color"
            android:resource="@color/godot_color" />

    </application>
</manifest>
```

### 5. Configurar Gradle

Arquivo `android/build/build.gradle`:

```gradle
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath 'com.android.tools.build:gradle:7.4.2'
        classpath 'com.google.gms:google-services:4.3.15'
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

apply plugin: 'com.android.application'
apply plugin: 'com.google.gms.google-services'

android {
    compileSdkVersion 33
    buildToolsVersion "33.0.0"
    
    defaultConfig {
        applicationId "com.seunome.wordmix"
        minSdkVersion 21
        targetSdkVersion 33
        versionCode 1
        versionName "1.0"
        
        multiDexEnabled true
    }
    
    buildTypes {
        release {
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
    
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_11
        targetCompatibility JavaVersion.VERSION_11
    }
}

dependencies {
    implementation 'androidx.multidex:multidex:2.0.1'
    
    // Firebase
    implementation platform('com.google.firebase:firebase-bom:32.7.0')
    implementation 'com.google.firebase:firebase-auth'
    implementation 'com.google.firebase:firebase-database'
    implementation 'com.google.firebase:firebase-analytics'
    
    // Play Services
    implementation 'com.google.android.gms:play-services-auth:20.7.0'
}
```

### 6. Gerar APK

#### Debug:
```bash
# Via Godot Editor
Project → Export → Android → Export Project

# Via linha de comando
godot --headless --export-debug "Android" wordmix_debug.apk
```

#### Release:
```bash
# Configurar keystore de release primeiro
keytool -genkey -v -keystore wordmix-release.keystore -alias wordmix -keyalg RSA -keysize 2048 -validity 10000

# Exportar release
godot --headless --export-release "Android" wordmix_release.apk
```

## 🍎 Exportação iOS

### 1. Configurar Xcode

1. Instale Xcode da App Store
2. Instale Command Line Tools:
   ```bash
   xcode-select --install
   ```
3. Configure conta de desenvolvedor Apple

### 2. Criar Preset iOS

1. **Project → Export**
2. **Add → iOS**
3. Configure:

#### Application:
```
App Store Team ID: [Seu Team ID]
Bundle Identifier: com.seunome.wordmix
Name: Wordmix
Info: Jogo de palavras com sincronização
Version: 1.0
Short Version: 1.0
```

#### Required Icons:
```
App Icon 1024x1024: res://icons/ios_icon_1024.png
iPhone 120x120: res://icons/ios_icon_120.png
iPhone 180x180: res://icons/ios_icon_180.png
iPad 152x152: res://icons/ios_icon_152.png
iPad 167x167: res://icons/ios_icon_167.png
```

#### Optional Icons:
```
Spotlight 80x80: res://icons/ios_spotlight_80.png
Settings 58x58: res://icons/ios_settings_58.png
```

#### Landscape Launch Images:
```
iPhone 2436x1125: res://launch/iphone_x_landscape.png
iPad 2048x1536: res://launch/ipad_landscape.png
```

#### Portrait Launch Images:
```
iPhone 1125x2436: res://launch/iphone_x_portrait.png
iPad 1536x2048: res://launch/ipad_portrait.png
```

### 3. Configurar Info.plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>Wordmix</string>
    
    <key>CFBundleIdentifier</key>
    <string>com.seunome.wordmix</string>
    
    <key>CFBundleVersion</key>
    <string>1.0</string>
    
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    
    <!-- Orientações suportadas -->
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationPortraitUpsideDown</string>
    </array>
    
    <!-- Configurações de rede -->
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
    
    <!-- Firebase URL Schemes -->
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>REVERSED_CLIENT_ID</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>YOUR_REVERSED_CLIENT_ID_FROM_PLIST</string>
            </array>
        </dict>
    </array>
    
    <!-- Privacidade -->
    <key>NSUserTrackingUsageDescription</key>
    <string>Este app usa dados para melhorar a experiência de jogo.</string>
    
    <!-- Requer iOS 12.0+ -->
    <key>MinimumOSVersion</key>
    <string>12.0</string>
    
    <!-- Suporte a dispositivos -->
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>armv7</string>
    </array>
</dict>
</plist>
```

### 4. Gerar Projeto Xcode

```bash
# Via Godot Editor
Project → Export → iOS → Export Project

# Via linha de comando
godot --headless --export-debug "iOS" wordmix_ios/
```

### 5. Configurar no Xcode

1. Abra `wordmix_ios.xcodeproj` no Xcode
2. Configure **Signing & Capabilities**:
   - Team: Sua conta de desenvolvedor
   - Bundle Identifier: `com.seunome.wordmix`
   - Signing Certificate: Automático
3. Adicione **Capabilities**:
   - Push Notifications (se usar)
   - Background Modes → Background fetch
4. Configure **Build Settings**:
   - iOS Deployment Target: 12.0
   - Architecture: arm64

### 6. Build e Deploy

#### Simulador:
```bash
# Selecione simulador no Xcode e clique em Run
```

#### Dispositivo:
```bash
# Conecte dispositivo iOS
# Selecione dispositivo no Xcode
# Build → Run
```

#### App Store:
```bash
# Product → Archive
# Window → Organizer
# Distribute App → App Store Connect
```

## 🎨 Otimizações para Mobile

### 1. Configurações de Performance

```gdscript
# Em Global.gd
func _ready():
    # Otimizações para mobile
    if OS.has_feature("mobile"):
        Engine.max_fps = 60
        get_viewport().render_info_type_visible = false
        
        # Reduz qualidade gráfica se necessário
        if OS.get_processor_count() < 4:
            ProjectSettings.set_setting("rendering/quality/driver/driver_name", "GLES2")
```

### 2. Interface Touch-Friendly

```gdscript
# Tamanhos mínimos para botões
const MIN_BUTTON_SIZE = Vector2(44, 44)  # 44dp mínimo iOS/Android

# Detectar gestos
func _input(event):
    if event is InputEventScreenTouch:
        if event.pressed:
            _handle_touch_start(event.position)
        else:
            _handle_touch_end(event.position)
    
    elif event is InputEventScreenDrag:
        _handle_touch_drag(event.position, event.relative)
```

### 3. Gerenciamento de Memória

```gdscript
# Liberar recursos não utilizados
func _notification(what):
    match what:
        NOTIFICATION_WM_FOCUS_OUT:
            # App perdeu foco - liberar recursos
            _cleanup_unused_resources()
        
        NOTIFICATION_WM_FOCUS_IN:
            # App ganhou foco - recarregar se necessário
            _restore_resources()

func _cleanup_unused_resources():
    # Limpar texturas não essenciais
    for texture in cached_textures:
        if not texture.is_essential:
            texture.queue_free()
```

## 🔧 Troubleshooting

### Problemas Comuns Android:

1. **Build falha**: Verifique versões do SDK e Gradle
2. **App não instala**: Confirme assinatura e permissões
3. **Firebase não conecta**: Verifique `google-services.json`
4. **Performance baixa**: Ative GLES2 em dispositivos antigos

### Problemas Comuns iOS:

1. **Certificado inválido**: Renove certificados no Apple Developer
2. **App rejeitado**: Verifique guidelines da App Store
3. **Crash no launch**: Verifique Info.plist e dependências
4. **Firebase não funciona**: Confirme `GoogleService-Info.plist`

### Comandos de Debug:

```bash
# Android - Ver logs
adb logcat | grep Godot

# iOS - Ver logs no Xcode
Window → Devices and Simulators → View Device Logs
```

## 📊 Checklist de Release

### Antes do Release:

- [ ] Testes em dispositivos reais
- [ ] Verificar performance em dispositivos antigos
- [ ] Testar conectividade online/offline
- [ ] Validar sincronização Firebase
- [ ] Verificar todas as telas/resoluções
- [ ] Testar compras in-app (se aplicável)
- [ ] Revisar permissões necessárias
- [ ] Configurar analytics e crash reporting

### Configurações de Store:

#### Google Play Store:
- [ ] Screenshots (mínimo 2 por categoria)
- [ ] Ícone da app (512x512)
- [ ] Descrição otimizada para SEO
- [ ] Classificação etária apropriada
- [ ] Política de privacidade
- [ ] Configurar preço (gratuito/pago)

#### Apple App Store:
- [ ] Screenshots para todos os tamanhos
- [ ] Ícone da app (1024x1024)
- [ ] Descrição e palavras-chave
- [ ] Classificação etária
- [ ] Política de privacidade
- [ ] Configurar preço e disponibilidade

## 📈 Pós-Launch

### Monitoramento:
- Firebase Analytics
- Crash reports
- User feedback
- Performance metrics
- Revenue tracking (se aplicável)

### Atualizações:
- Correções de bugs
- Novos recursos
- Otimizações de performance
- Atualizações de segurança

---

**Última atualização**: Janeiro 2025
**Versão**: 1.0
**Compatibilidade**: Godot 4.x, Android 5.0+, iOS 12.0+