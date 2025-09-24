# Keystores do WordMix

Este documento contém as informações dos keystores gerados para o projeto WordMix.

## Keystore de Debug (debug.keystore)

- **Arquivo**: `debug.keystore`
- **Alias**: `debug`
- **Senha do Keystore**: `android`
- **Senha da Chave**: `android`
- **Algoritmo**: RSA 2048 bits
- **Validade**: 10.000 dias (~27 anos)
- **Uso**: Para builds de desenvolvimento e teste

### Informações do Certificado:
- **CN**: Debug
- **OU**: WordMix
- **O**: WordMix
- **L**: Debug
- **ST**: Debug
- **C**: BR

## Keystore de Lançamento (release.keystore)

- **Arquivo**: `release.keystore`
- **Alias**: `release`
- **Senha do Keystore**: `wordmix2024`
- **Senha da Chave**: `wordmix2024`
- **Algoritmo**: RSA 2048 bits
- **Validade**: 25.000 dias (~68 anos)
- **Uso**: Para builds de produção e publicação

### Informações do Certificado:
- **CN**: WordMix
- **OU**: WordMix Games
- **O**: WordMix Studio
- **L**: Sao Paulo
- **ST**: SP
- **C**: BR

## Configuração no Godot

Para usar esses keystores no Godot:

1. Vá em **Project > Export**
2. Selecione **Android**
3. Na seção **Keystore**:
   - **Debug Keystore**: Aponte para `debug.keystore`
   - **Debug Keystore User**: `debug`
   - **Debug Keystore Password**: `android`
   - **Release Keystore**: Aponte para `release.keystore`
   - **Release Keystore User**: `release`
   - **Release Keystore Password**: `wordmix2024`

## Segurança

⚠️ **IMPORTANTE**: 
- Mantenha o keystore de lançamento em local seguro
- Faça backup do keystore de lançamento
- Nunca compartilhe as senhas publicamente
- O keystore de debug pode ser compartilhado para desenvolvimento em equipe