# Lembrete diário via push (Firebase + Supabase)

Como o lembrete diário funciona hoje e comandos úteis pra depurar/manter.
Complementa a seção "Supabase (banco remoto)" de
`docs/adb-testing-cheatsheet.md` (mesmo fluxo de `psql`/pooler).

## Como funciona

1. App (logado) ativa "Lembrete diário" em Configurações →
   `PushNotificationService` (`lib/services/push_notification_service.dart`)
   pega o token FCM do device + fuso IANA e grava em
   `push_subscriptions` via `PushSubscriptionRepository`
   (`lib/data/repositories/push_subscription_repository.dart`).
2. Um cron job do Postgres (`pg_cron`, criado em
   `supabase/migrations/0007_push_subscriptions.sql`) chama a Edge Function
   `send-daily-reminders` via HTTP a cada minuto.
3. A função (`supabase/functions/send-daily-reminders/index.ts`) lê todo
   mundo em `push_subscriptions` (service role, ignora RLS), calcula a hora
   local de cada um a partir do fuso salvo, e manda push via FCM HTTP v1 pra
   quem bater `reminder_hour`/`reminder_minute` agora.
4. Token que o FCM reporta como inválido/não registrado é apagado da tabela
   automaticamente pela própria função.

Sem login não há push (RLS é por `user_id`) — o toggle fica desabilitado
nesse caso, ver `lib/screens/settings/settings_screen.dart`.

## Onde ficam os segredos

- **Service account do Firebase** (Console Firebase > Project Settings >
  Service accounts > Generate new private key): colado como secret
  `FCM_SERVICE_ACCOUNT_JSON` em Supabase Dashboard > Edge Functions >
  Secrets. Não fica em nenhum arquivo do repo.
- **Service role key do Supabase**: guardada no Vault do Postgres (rodado
  manualmente no SQL Editor, não versionado):
  ```sql
  select vault.create_secret('<service_role_key>', 'service_role_key');
  ```
  Usada pelo cron job pra autenticar a chamada HTTP na Edge Function. Pra
  trocar (rotacionou a chave, por exemplo):
  ```sql
  select vault.update_secret(
    (select id from vault.secrets where name = 'service_role_key'),
    '<nova_service_role_key>'
  );
  ```
- `SUPABASE_URL`/`SUPABASE_SERVICE_ROLE_KEY` dentro da própria Edge Function
  são injetados automaticamente pelo runtime — não precisam de configuração.

## Comandos úteis

Todos assumem Git Bash na raiz do projeto, com `.env` presente (tem
`SUPABASE_DB_PASSWORD`). Ver a seção "Supabase (banco remoto)" do
`adb-testing-cheatsheet.md` pra por que usar o pooler em vez do host direto.

```bash
PGPASSWORD="$(grep -m1 '^SUPABASE_DB_PASSWORD=' .env | cut -d= -f2-)" \
  psql -h aws-0-us-east-2.pooler.supabase.com -p 5432 \
  -U postgres.szgtwzltwlylcgtwhlvx -d postgres -v ON_ERROR_STOP=1 -c "<SQL>"
```

**Ver as últimas execuções do cron job** (sucesso/erro de cada chamada por
minuto — primeiro lugar pra olhar se o push parou de chegar):
```sql
select status, return_message, start_time
from cron.job_run_details
where jobid = (select jobid from cron.job where jobname = 'send-daily-reminders-every-minute')
order by start_time desc
limit 10;
```

**Ver quem está inscrito** (conferir se o token/horário/fuso salvos batem
com o esperado):
```sql
select user_id, platform, reminder_hour, reminder_minute, timezone, updated_at
from push_subscriptions
order by updated_at desc;
```

**Disparar pra um usuário específico agora, sem depender do horário
configurado** — passa `userId` no corpo; a função ignora o check de
horário só pra esse usuário (não mexe na linha em `push_subscriptions`,
não afeta o cron):
```bash
curl -i -X POST "https://szgtwzltwlylcgtwhlvx.supabase.co/functions/v1/send-daily-reminders" \
  -H "Authorization: Bearer <service_role_key>" \
  -H "Content-Type: application/json" \
  -d '{"userId": "<uuid-do-usuario>"}'
```

**Invocar a Edge Function sem `userId`** (mesmo comportamento do cron —
só dispara pra quem estiver na hora certa agora; útil pra testar uma
mudança no código dela sem esperar o próximo minuto):
```bash
curl -i -X POST "https://szgtwzltwlylcgtwhlvx.supabase.co/functions/v1/send-daily-reminders" \
  -H "Authorization: Bearer <service_role_key>" \
  -H "Content-Type: application/json" -d '{}'
```

Em ambos os casos, a service role key não deve ser commitada em lugar
nenhum — pega em Project Settings > API > `service_role` no painel do
Supabase.

**Pausar/retomar o cron job** (ex: enquanto depura algo, pra não gastar
invocações da Edge Function):
```sql
-- pausar:
select cron.alter_job((select jobid from cron.job where jobname = 'send-daily-reminders-every-minute'), active := false);
-- retomar:
select cron.alter_job((select jobid from cron.job where jobname = 'send-daily-reminders-every-minute'), active := true);
```

**Ver logs da Edge Function** (exceções, `console.log`, etc.): Supabase
Dashboard > Edge Functions > `send-daily-reminders` > Logs. Não tem CLI do
Supabase instalada neste projeto (ver `adb-testing-cheatsheet.md`), então
redeploy de mudanças na função também é pelo Dashboard (cola o conteúdo
novo de `index.ts` e clica em Deploy) — ou instala a CLI
(`npm i -g supabase`) e usa `supabase functions deploy send-daily-reminders`.

## Pendências conhecidas

- iOS ainda não está registrado no Firebase (app Android only por enquanto)
  — falta subir `GoogleService-Info.plist` em `ios/Runner/` e habilitar as
  capabilities Push Notifications + Background Modes no Xcode. Até lá, o
  código funciona normalmente no Android; no iOS o botão de ativar lembrete
  pede permissão mas o `FirebaseMessaging.instance.getToken()` falha
  silenciosamente (guard `_ready` em `PushNotificationService`).
