# Fonte do dicionário bíblico

`easton_smith.json` vem de https://github.com/neuu-org/bible-dictionary-dataset
(pasta `data/01_parsed/`, arquivos `a.json`–`z.json`), mesclado em um único
array ordenado alfabeticamente por termo. 5.998 verbetes.

- **Conteúdo original**: Easton's Bible Dictionary (1897) e Smith's Bible
  Dictionary (1863) — ambos em domínio público, **só em inglês** (não existe
  tradução completa/confiável em português pra esses dois).
- **Empacotamento/dataset** (o parsing pra JSON): licença CC BY 4.0, pelo
  próprio repositório de origem.

Formato de cada entrada:
```json
{"term": "Aaron", "definitions": [{"source": "EAS", "text": "..."}, {"source": "SMI", "text": "..."}], "refs": ["Exodus 4:14", ...]}
```
## `terms_pt.json`

Tradução para o português **só dos termos** (não das definições): objeto
`{"<term em inglês>": "<termo em português>"}` com uma chave para cada um
dos 5.998 `term` de `easton_smith.json`. Nomes próprios seguem a grafia da
Almeida (ex: Aaron → Arão, Nebuchadnezzar → Nabucodonosor). Feita à parte,
em vez de editar `easton_smith.json`, pra manter o dataset de origem intacto.
A busca do dicionário aceita os dois idiomas.

## Formato de `easton_smith.json`

`source` é `EAS` (Easton) ou `SMI` (Smith) — um termo pode ter definição das
duas fontes. `refs` são referências bíblicas já normalizadas (ex: "Exodus
4:14"), em inglês (nome do livro), não convertidas pros ids do app.
