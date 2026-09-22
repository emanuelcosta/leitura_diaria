# Comandos ADB usados para testar o app manualmente

Referência dos comandos usados para instalar, navegar e tirar screenshot do
app no celular físico (Redmi Note 12S, conectado via Wi-Fi/ADB) durante o
desenvolvimento. Todos os exemplos assumem Git Bash no Windows.

## Ambiente

- **Sempre exportar `MSYS_NO_PATHCONV=1`** antes de comandos `adb shell`/`pull`
  que usam caminhos começando com `/` (ex: `/sdcard/...`). Sem isso, o Git
  Bash reescreve `/sdcard/screen.png` para algo como
  `C:/Program Files/Git/sdcard/screen.png` e o comando falha.

```bash
export MSYS_NO_PATHCONV=1
```

- Identificar o device id (varia por conexão):

```bash
adb devices
# ex: adb-TCIRDYJ7LROJTGI7-msWdht._adb-tls-connect._tcp   device
```

Todos os comandos abaixo usam `-s <device-id>` para mirar um device
específico quando há mais de um conectado (celular físico + emulador).

## Rodar o app

```bash
flutter run -d <device-id>
```

- Se o instalador falhar com `INSTALL_FAILED_USER_RESTRICTED: Install
  canceled by user`, é o Android pedindo confirmação manual na tela do
  celular (aparece um diálogo "Permitir instalação?"). É preciso desbloquear
  o aparelho e tocar em "Instalar"/"Permitir" — não dá pra automatizar isso
  via ADB.
- Rodar em background (`run_in_background: true` no Bash tool) e usar um
  `until grep -q ... ; do sleep N; done` no output para saber quando o build
  terminou, em vez de ficar sondando.

## Emulador Android (alternativa ao celular físico)

```bash
flutter emulators                          # lista emuladores disponíveis
flutter emulators --launch Pixel6_API34    # inicia (processo assíncrono)
# esperar até aparecer como "device" (não "offline"):
until adb devices | grep -q "emulator.*device$"; do sleep 3; done
```

## Screenshot

```bash
adb -s <device-id> shell screencap -p /sdcard/screen.png
adb -s <device-id> pull /sdcard/screen.png "<caminho-local>/screen.png"
```

Depois é só usar a ferramenta `Read` no PNG salvo. O resultado do `pull` vem
com o tamanho na resolução real do device (ex: 1080x2400), mas a imagem é
exibida redimensionada — a mensagem de retorno indica o fator de conversão
(ex: "displayed at 900x2000, multiply by 1.20") para converter as
coordenadas visuais em coordenadas reais antes de usar em `input tap`.

## Tocar na tela

```bash
adb -s <device-id> shell input tap <x> <y>
```

Coordenadas em pixels reais do device (não da imagem redimensionada — ver
nota acima sobre o fator de conversão).

## Digitar texto

```bash
adb -s <device-id> shell input text "Deus%screou%so%smundo%sem%s6%sdias."
```

- **Espaço tem que ser `%s`**, não `%20` — `input text` não faz URL-decode,
  então `%20` aparece literalmente no campo.
- Para limpar um campo antes de redigitar, não tem "select all" fácil via
  ADB: mais simples é mandar vários `keyevent 67` (backspace) em sequência.

## Botões do sistema (keyevent)

```bash
adb -s <device-id> shell input keyevent 4    # Voltar (back)
adb -s <device-id> shell input keyevent 67   # Backspace/Delete
```

Cuidado: apertar "voltar" na tela raiz do app (sem mais nada na pilha de
navegação) sai do app para a home screen do Android, não fecha o app.

## Reabrir/parar o app

```bash
# Reabrir (útil depois de cair na home screen sem querer):
adb -s <device-id> shell am start -n <applicationId>/.MainActivity

# Forçar parada (equivalente a "fechar" o app):
adb -s <device-id> shell am force-stop <applicationId>

# Desinstalar (ex: depois de trocar o applicationId no build.gradle.kts,
# o app antigo fica órfão sob o pacote antigo):
adb -s <device-id> uninstall <applicationId-antigo>
```

`applicationId` atual do projeto: `com.emanuel.leituradiaria` (era
`com.example.leitura_diaria` antes do rebrand).

## Supabase (banco remoto)

Comandos pra aplicar migrations direto no Postgres do projeto Supabase (não
precisa da CLI do Supabase instalada — `psql` já resolve):

```bash
# Credenciais ficam em .env (não versionado) / senhas.md — nunca colar a
# senha em texto puro num comando/histórico compartilhado. Este comando lê
# a senha direto do .env, sem precisar de um passo separado de `export`.
PGPASSWORD="$(grep -m1 '^SUPABASE_DB_PASSWORD=' .env | cut -d= -f2-)" \
  psql -h aws-0-us-east-2.pooler.supabase.com -p 5432 \
  -U postgres.<project-ref> -d postgres -v ON_ERROR_STOP=1 \
  -f supabase/migrations/000X_nome.sql
```

- `<project-ref>` é o subdomínio da `SUPABASE_URL` (ex: URL
  `https://szgtwzltwlylcgtwhlvx.supabase.co` → ref `szgtwzltwlylcgtwhlvx`).
- **Usar o connection pooler (Session pooler), não o host `db.<project-ref>.supabase.co`
  direto** — o host direto só resolve em IPv6 e dá `Connection timed out` em
  redes sem rota IPv6 funcionando. Host/usuário do pooler ficam em Project
  Settings > Database > Connection string > "Session pooler" no painel do
  Supabase (username vem no formato `postgres.<project-ref>`, diferente do
  `postgres` puro da conexão direta).
- A senha do banco tem caracteres especiais (backtick, `<`, `[`); sempre usar
  aspas simples ao redor do valor pra não deixar o shell interpretar nada —
  por isso o comando acima já extrai ela com `cut` em vez de colar solto.
- Migrations do projeto ficam em `supabase/migrations/`; cada arquivo é
  idempotente (`create table if not exists`, `create index if not exists`) —
  seguro rodar de novo se não tiver certeza se já foi aplicado.

## Notificação/cortina do sistema atrapalhando

Notificações reais do celular (WhatsApp, apps do dia a dia) às vezes abrem
como heads-up por cima do app durante os testes e desviam o toque seguinte
para o local errado (já aconteceu de abrir Configurações do Android por
engano). Se isso acontecer: um `keyevent 4` fecha a notificação, um segundo
`screencap` confirma que voltou pro app antes de continuar tocando.
