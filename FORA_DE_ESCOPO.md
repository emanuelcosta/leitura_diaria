# Demandas fora de escopo

Itens identificados durante o desenvolvimento que não foram tratados por não
fazerem parte do que foi pedido até agora. Ficam aqui para decisão futura.

## Suporte a desktop/web

`sqflite` não funciona em Chrome/Edge (web) nem em Windows/macOS/Linux
desktop sem configurar `sqflite_common_ffi` no `AppDatabase._open()` (hoje só
usado em testes). Só Android/iOS funcionam sem ajuste. Não mexido porque o
app é pensado para celular.

## Backend com Supabase: UI otimista

O schema (`chapter_progress` com RLS), o login por email/senha (Supabase
Auth) e a sincronização em si (push a cada mutação local, pull/merge no
login) já estão implementados — ver `SyncRepository`, `AuthProvider` e os
métodos `_push*`/`pullFromRemoteAndMerge` em `ReadingPlanProvider`. A decisão
de arquitetura foi acessar o Supabase direto do Flutter com Row Level
Security, sem servidor Express intermediário (o Supabase não hospeda Express
de qualquer forma — só Postgres/Auth/Storage/Edge Functions em Deno).

Ainda falta a parte de UX: tornar as operações do app (marcar capítulo lido,
salvar nota, etc.) assíncronas/otimistas na UI, para não recarregar a tela
bruscamente a cada ação — hoje cada `setChapterRead`/`setChapterNote` dispara
`notifyListeners()` e refaz o `FutureBuilder` da tela inteira (o próprio
gravar local já é rápido; o ponto é evitar o flicker de rebuild, não a
latência de rede). Isso é uma refatoração maior de estado, ortogonal ao
Supabase, que toca a maioria das telas (`TodayScreen`, `BookChaptersScreen`,
`BookProgressScreen`, `DashboardScreen`, `HeatmapScreen`) — melhor tratar
como uma tarefa própria.

