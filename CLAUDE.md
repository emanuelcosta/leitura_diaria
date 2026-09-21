# CLAUDE.md

Instruções para trabalhar neste repositório (Flutter/Dart). Objetivo: manter
o padrão de qualidade já estabelecido no código existente — não é um
documento aspiracional, é o que o código já faz e deve continuar fazendo.

## Comandos

```bash
flutter pub get                     # instalar/atualizar dependências
flutter analyze                     # SEMPRE rodar antes de considerar uma mudança pronta
flutter test                        # idem
flutter run -d <device-id>          # ver docs/adb-testing-cheatsheet.md para fluxo com device físico
```

Migrations do Supabase: ver `supabase/migrations/*.sql` e a seção "Supabase"
em `docs/adb-testing-cheatsheet.md` para aplicar via `psql`.

## Arquitetura

Camadas, de baixo para cima — uma tela nunca deve pular camada e falar
direto com `sqflite`/`Supabase`:

```
lib/data/models/          # classes de dados imutáveis: fromMap/fromJson/toMap, sem lógica de negócio
lib/data/database/        # AppDatabase (schema/migrations), queries compartilhadas
lib/data/repositories/    # uma classe por agregado; única camada que toca DB/Supabase
lib/logic/                # funções/classes puras (sem Flutter, sem DB) — cálculo, não I/O
lib/state/                # ChangeNotifier por feature; orquestra repositório(s), expõe estado pra UI
lib/screens/<feature>/    # uma tela por arquivo; widgets/ dentro de cada feature pros componentes que só ela usa
lib/services/             # integrações externas que não são "dados" (notificações, auth client)
lib/widgets/              # componentes genéricos reusados por 2+ features (EmptyState, ConfirmDialog...)
```

Exemplo de fluxo completo (favoritar um versículo): `FavoritesProvider`
(state) chama `FavoriteVerseRepository` (local) e `FavoriteSyncRepository`
(Supabase, opcional) — a tela (`ChapterReadingScreen`) só conhece o
provider. Repita esse formato para qualquer novo dado do usuário.

## Padrões de projeto já em uso — siga-os em vez de inventar um novo

- **Repository**: uma classe por tabela/agregado (`ChapterRepository`,
  `FavoriteVerseRepository`, `VerseNoteRepository`...). Método por operação,
  sem lógica de UI, sem `BuildContext`.
- **Observer via `ChangeNotifier`/`Provider`**: cada feature de estado
  compartilhado é um `ChangeNotifier` próprio (`ReadingPlanProvider`,
  `FavoritesProvider`, `SettingsProvider`...). Não amontoe estados não
  relacionados no mesmo provider.
- **Sync opcional por injeção de dependência**: todo repositório de sync
  (`SyncRepository`, `FavoriteSyncRepository`, `VerseNoteSyncRepository`) é
  `nullable` no provider — `null` quando o Supabase não está configurado
  (ver `main.dart`), e todo método de push é fire-and-forget
  (`unawaited(...).catchError((_) {})`) pra nunca travar a UI numa operação
  de rede. Pull/merge roda uma vez no login (`pullFromRemoteAndMerge`,
  disparado por `Supabase...auth.onAuthStateChange`).
- **Factory constructors** (`fromMap`, `fromJson`, `fromCode`) nos models —
  não parseie JSON/SQL fora do model.
- **Enums com dados anexados** em vez de strings mágicas ou `if/else`
  encadeado (`BibleTranslation`, `BookCategory`) — ver `categoryForOrder` em
  `lib/data/models/book.dart` como "strategy" simples baseada em enum.
- **Migrations idempotentes**: toda migration em `supabase/migrations/`
  usa `create table if not exists` / `drop policy if exists` + `create
  policy`, porque pode ser reaplicada sem erro. Local: `AppDatabase` usa
  `onUpgrade` incremental por versão, nunca `DROP TABLE`.

## SOLID neste projeto (aplicação prática, não teoria)

- **S**: um repositório = uma responsabilidade de dado. Se um método não se
  encaixa no propósito da classe (ex: lógica de agendamento dentro de um
  repositório de capítulos), ele pertence a `lib/logic/` ou a outro
  repositório.
- **O**: para adicionar uma tradução da Bíblia, um filtro, ou uma categoria,
  estenda o enum/dado (`BibleTranslation`, `BookCategory`) em vez de
  espalhar `if (nome == 'ACF')` pelo código.
- **L**: os `Sync*Repository` são todos substituíveis por `null` sem que o
  código que os chama precise saber a diferença (ver `ReadingPlanProvider`,
  que funciona idêntico com ou sem Supabase configurado).
- **I**: telas dependem só do provider que realmente usam
  (`context.watch<FavoritesProvider>()`, não um "AppProvider" gigante com
  tudo dentro).
- **D**: uma tela nunca instancia `Supabase.instance.client` ou abre o
  `Database` diretamente — sempre via repositório/provider injetado
  (repositórios aceitam ser passados no construtor pra permitir fakes nos
  testes, ver `ChapterRepository? chapterRepo` em `ReadingPlanProvider`).

## Componentização

- Extraia um widget para `widgets/` da própria feature quando: (a) é usado
  em mais de um lugar, ou (b) o `build()` do arquivo pai passa de ~150
  linhas, ou (c) tem estado próprio que não faz sentido no widget pai.
- Nomeie pelo papel, não pelo conteúdo: `*Screen` (tela cheia, tem
  `Scaffold`), `*Card`/`*Tile` (item de lista), `*Section` (agrupador),
  `*Panel` (bloco reusável sem `Scaffold` próprio, ex: `VerseSearchPanel`),
  `*Dialog` (modal). Veja `lib/screens/progress/widgets/` como referência.
- Um widget não busca dado que a tela já tem — recebe por parâmetro
  (`BookProgressTile(progress: b)`, não `BookProgressTile(bookId: id)`
  buscando de novo).
- `StatelessWidget` é o padrão; só vira `StatefulWidget` quando há de fato
  estado local (texto de campo, expandido/colapsado, seleção). Estado que
  precisa sobreviver entre telas ou ser lido por outro widget vai pro
  `ChangeNotifier`, não pro `State`.

## Coisas específicas deste projeto que já foram decididas — não reabrir sem motivo

- Acesso ao Supabase é direto do Flutter + Row Level Security, sem backend
  intermediário (ver `FORA_DE_ESCOPO.md` — o Supabase não hospeda Express).
- Todo dado do usuário (progresso, favoritos, notas) é local-first: grava
  no SQLite primeiro, sincroniza depois em background. A tela nunca espera
  a rede pra atualizar.
- Erros de sync são engolidos silenciosamente por enquanto (`catchError((_)
  {})`) — é uma lacuna conhecida, não repita sem pelo menos comentar que é
  proposital.
- Busca de texto (nomes de livro, versículos) sempre ignora acento —
  `normalizeForSearch` em `lib/logic/text_normalize.dart`, não reimplemente.
- Um painel que pode crescer bastante (busca de versículos, listas longas)
  abre como modal (`showModalBottomSheet`), nunca empurra o conteúdo
  principal pra baixo.

## Testes

- `test/logic/` cobre funções puras (sem DB/Flutter) com casos de borda
  explícitos no nome do teste (`schedule_calculator_test.dart`).
- `test/data/` usa `sqflite_common_ffi` com banco em memória — sempre criar
  schema real via `AppDatabase.createSchema(db)`, nunca mockar o SQL.
- Novo repositório ou provider com lógica não trivial precisa de teste indo
  junto na mesma mudança, não depois.
