# Demandas fora de escopo

Itens identificados durante o desenvolvimento que não foram tratados por não
fazerem parte do que foi pedido até agora. Ficam aqui para decisão futura.

## Identidade do app nas demais plataformas

Só o Android foi rebrandeado (`com.emanuel.leituradiaria` / "Bíblia em 1 Ano"),
porque é a única plataforma testada até agora. Ainda usam o nome padrão do
template Flutter (`com.example.*` / "leitura_diaria"):

- `ios/Runner.xcodeproj/project.pbxproj` (PRODUCT_BUNDLE_IDENTIFIER)
- `ios/Runner/Info.plist` (CFBundleDisplayName / CFBundleName)
- `macos/Runner.xcodeproj/project.pbxproj` e `macos/Runner/Configs/AppInfo.xcconfig`
- `linux/CMakeLists.txt` (BINARY_NAME / APPLICATION_ID)
- `windows/runner/Runner.rc`, `windows/runner/main.cpp`, `windows/CMakeLists.txt`

## Suporte a desktop/web

`sqflite` não funciona em Chrome/Edge (web) nem em Windows/macOS/Linux
desktop sem configurar `sqflite_common_ffi` no `AppDatabase._open()` (hoje só
usado em testes). Só Android/iOS funcionam sem ajuste. Não mexido porque o
app é pensado para celular.

## Tela de Livros: filtros, marcar tudo e agrupamentos

- Filtro na tela "Livros" (ex: por testamento, por lido/não lido, por nome).
- Opção de marcar todos os capítulos de um livro como lido de uma vez (hoje
  só dá para marcar capítulo por capítulo em `BookChaptersScreen`).
- Agrupamento de livros por categoria (histórico, poético, evangelhos,
  cartas, profético etc.), não só por Antigo/Novo Testamento como hoje.

## Aviso de SQL

Log do dispositivo mostrou `W/SQLiteLog: double-quoted string literal: ""`
vindo de `ChapterRepository.getChaptersWithNotes()` (comparação
`note != ""` usa aspas duplas, que o SQLite trata como identificador
depreciado). Não quebra nada hoje, mas seria bom trocar para aspas simples.
