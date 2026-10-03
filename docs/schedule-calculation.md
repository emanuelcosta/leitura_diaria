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
5. **Meta diária e previsão de conclusão** (`requiredUnitsPerDay` e
   `projectedFinishDate`): a previsão usa o prazo configurado, em vez de
   extrapolar uma média histórica:
   ```
   dataAlvo        = início + prazoEmDias − 1
   diasDisponíveis = max(1, dataAlvo − hoje + 1)
   faltam          = totalDeUnidades − unidadesLidas
   metaPorDia      = ceil(faltam / diasDisponíveis)
   previsão        = hoje + ceil(faltam / metaPorDia) dias
   ```
   A unidade é capítulo ou versículo conforme o modo de progresso selecionado.
   Como a divisão é arredondada para cima, a meta nunca fica abaixo do
   necessário para cumprir o prazo.

6. **Previsão pelo histórico** (`historicalProjectedFinishDate`): é calculada
   usando a **mediana** da quantidade de capítulos dos dias em que houve
   pelo menos um capítulo lido:
   ```
   ritmoTípico = mediana(capítulosLidosEmCadaDiaAtivo)
   previsãoHistórica = hoje + ceil(capítulosRestantes / ritmoTípico)
   ```
   A mediana reduz o impacto de um dia atípico, como marcar muitos livros de
   uma vez no primeiro dia. Essa é a previsão principal pelo ritmo observado.
   O card também mostra
   `calendarProjectedFinishDate`, uma estimativa conservadora que divide os
   capítulos lidos por todos os dias desde o início, incluindo dias sem
   leitura. Quando nenhum capítulo foi lido, as duas previsões não são exibidas.

## Detalhe não-óbvio corrigido nesta revisão

`DashboardScreen` chamava `computeScheduleStatus` sem passar `lastReadAt`,
então o card de conclusão nunca mostrava "Concluído em DD/MM/AAAA" (o campo
ficava sempre nulo). Agora, quando `progress.readCount >= progress.totalCount`,
a tela busca a data via `plan.getLastReadAt()` antes de montar o card.
