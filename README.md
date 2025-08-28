# Wordmix (Godot 4) — v2

Protótipo estilo Wordle com **teclado na tela** e **modos Diário/Infinito**.
Pronto para abrir, rodar e exportar para Android.

## Rodar no PC
1. Instale **Godot 4.x**.
2. Abra `project.godot` e pressione **F5**.

## Jogar
- Use o **teclado na tela** para digitar, `ENTER` para enviar e `⌫` para apagar.
- **Modo Diário**: uma palavra por dia (determinística).
- **Modo Infinito**: palavras aleatórias. Clique em **Novo Jogo** para sortear outra.

## Estrutura
- `scenes/Main.tscn` — cena principal (grid + status + teclado + topo).
- `scripts/Main.gd` — lógica (checagem, estados, modos, cores no teclado).
- `scenes/Keyboard.tscn` + `scripts/Keyboard.gd` — teclado virtual com cores por letra.
- `scenes/Tile.tscn` + `scripts/Tile.gd` — tile com estados.
- `data/words.txt` — palavras (5 letras, MAIÚSCULAS, sem acento).

## Exportar para Android (Google Play)
1. **Project > Install Android Build Template**.
2. Configure o **Android SDK + JDK** em `Editor > Editor Settings > Export > Android`.
3. Gere um keystore de release:
   ```bash
   keytool -genkeypair -v -storetype PKCS12 -keystore my-release-key.keystore -alias wordmix -keyalg RSA -keysize 2048 -validity 10000
   ```
4. Em **Project > Export**, edite o preset Android (ou use `export_presets.cfg`):
   - `package/unique_name = com.seuestudio.wordmix`
   - `version/code` (inteiro) e `version/name`
   - Keystore de release (caminho, user, senha)
5. Exporte **AAB** e envie no **Google Play Console**.

## Polimento sugerido
- Animações de flip/reveal nos tiles (Tween).
- Histórico de partidas (Save via `ConfigFile`).
- Normalização de acentos no input e lista.
- Palavras de 6+ letras ou dicionários temáticos.
- Localização para EN/ES/PT.

## Monetização (opcional)
- **AdMob** (intersticial entre partidas ou banner fixo no topo/rodapé).
- **Versão Premium** para remover anúncios (Google Play Billing).

Bom dev! :)


### Nota sobre versões do Godot
- **Godot 4.x:** o projeto usa `Time.get_unix_time_from_system()` para definir a palavra do dia.
- **Godot 3.x:** se for usar no 3.x, troque por:
  ```gdscript
  var date = OS.get_datetime()
  var days = int(date.year) * 372 + int(date.month) * 31 + int(date.day)
  var rng = RandomNumberGenerator.new()
  rng.seed = days
  ```
