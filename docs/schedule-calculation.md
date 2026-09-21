# Como a "Previsão de conclusão" é calculada

Código: `lib/logic/schedule_calculator.dart` (`ScheduleCalculator.computeStatus`),
chamado por `ReadingPlanProvider.computeScheduleStatus` e exibido em
`ScheduleStatusCard` (card "Cronograma" da tela Painel).

## Entradas

- `startDate` — data de início escolhida no onboarding/Configurações.
- `today` — `DateTime.now()` no momento da renderização (sem hora, só data).
- `actualReadCount` — total de capítulos com `is_read = 1` no banco local,
  **sem importar em que dia do plano cada um estava** (ler fora de ordem ou
  adiantado conta do mesmo jeito).
- `planCumulative[d]` — quantos capítulos distintos o plano introduz do dia 1
  até o dia `d` (construído uma vez em `ReadingPlanMeta` a partir de
  `assets/reading_plan.json`; `planCumulative[365] == 1189`, o total de
  capítulos da Bíblia).

## O cálculo, passo a passo

1. **Dia ideal do plano** (`idealPlanDay`): `hoje − início` em dias, +1,
   limitado entre 1 e 365. É "em que dia do plano eu deveria estar, se
   estivesse em dia".
2. **Concluído**: se `actualReadCount >= 1189`, o card mostra a mensagem de
   parabéns em vez do cronograma. `completionDate` vem de
   `ChapterRepository.getLastReadAt()` (o maior `read_at` salvo) — só é
   buscado quando o total bate (`DashboardScreen` só chama essa query nesse
   caso, pra não rodar um `MAX(read_at)` a cada render do painel).
3. **Dia alcançado** (`achievedPlanDay`): o menor dia `d` cujo
   `planCumulative[d]` já é ≥ `actualReadCount`. Ou seja, "quantos capítulos
   você já leu, na escala de dias do plano" — **não** verifica se foram os
   capítulos certos daquele dia, só a contagem.
4. **Adiantado/atrasado** (`daysAheadBehind`): `achievedPlanDay -
   idealPlanDay`. Positivo = à frente, negativo = atrás, 0 = em dia. É esse
   número que define a cor/ícone do card (verde/laranja/neutro).
5. **Previsão de conclusão** (`projectedFinishDate`): só é calculada se pelo
   menos 1 capítulo já foi lido. É uma **média linear simples desde o
   início**, não uma média móvel recente:
   ```
   diasDecorridos = (hoje − início) + 1
   médiaPorDia    = capítulosLidos / diasDecorridos
   faltam         = 1189 − capítulosLidos
   diasRestantes  = ceil(faltam / médiaPorDia)
   previsão       = hoje + diasRestantes dias
   ```
   Isso significa que um começo rápido (ou lento) segue puxando a média por
   muito tempo — a previsão reage devagar a uma mudança recente de ritmo. Não
   é um bug, é uma limitação de design conhecida: dá pra trocar por uma
   média das últimas N semanas se isso incomodar na prática.

## Detalhe não-óbvio corrigido nesta revisão

`DashboardScreen` chamava `computeScheduleStatus` sem passar `lastReadAt`,
então o card de conclusão nunca mostrava "Concluído em DD/MM/AAAA" (o campo
ficava sempre nulo). Agora, quando `progress.readCount >= progress.totalCount`,
a tela busca a data via `plan.getLastReadAt()` antes de montar o card.
