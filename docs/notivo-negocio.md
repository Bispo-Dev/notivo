# Notivo — Requisitos de negócio e experiência do usuário

> Versão 1.1, atualizada em 10/11/2026. Este documento descreve **o que o produto deve fazer**; a implementação e as limitações técnicas estão em `notivo-arquitetura.md`.

## Alterações desta versão

- **Salvamento automático é o único mecanismo de gravação das anotações.** O botão "Salvar rabiscos" foi removido do leitor.
- **Telas de referência em formato vertical (retrato)**, com design **minimalista**, ícones **Lucide** e **modo claro e escuro**.
- **Modo focado com o mínimo de ícones:** apenas uma pequena aba discreta no topo, que reabre abas e ferramentas.
- **Identidade visual atualizada** (manual de marca 1.0, revisado): o N musical passou a ser um contorno único com cantos arredondados, e a logo horizontal, o ícone do app e as regras de uso foram refinados.
- Novas decisões em aberto foram registradas na seção 11.

## 1. Identidade do produto

- **Nome:** Notivo.
- **Assinatura:** *Suas partituras, sempre à mão.*
- **Propósito:** guardar, organizar, consultar e anotar partituras em PDF com agilidade durante estudos, ensaios e apresentações.
- **Público:** músicos que utilizam tablet, especialmente com caneta digital, e alternam repertórios como **Orquestra, Banda, Igreja e Estudos**.
- **Princípios:** a **partitura é protagonista**; a interface é **minimalista**, exige poucos toques e ocupa o mínimo possível de tela durante a leitura.
- **Uso previsto:** local e offline, sem depender de conexão para abrir, pesquisar ou anotar arquivos já importados.
- **Orientação de referência:** tablet em **retrato** (telas de referência com 834 × 1194 px). A orientação horizontal continua sendo um uso esperado e precisa ser desenhada e validada (ver seção 11).

## 2. Fluxo principal

```text
Biblioteca (cards)
    ↓ tocar em coleção
Lista de partituras + busca
    ↓ tocar em partitura
Leitor de PDF em tela cheia
    ├─ abrir mais partituras (+) → novas abas
    ├─ caneta / grifador / borracha → anotações salvas automaticamente, com desfazer
    ├─ recolher abas e ferramentas → leitura focada
    └─ exportar → cópia do PDF com nome/anotações
```

Fluxo alternativo: selecionar várias partituras, inclusive **de coleções distintas**, e **abrir todas em abas** para um ensaio ou apresentação.

## 3. Biblioteca e cards

### Aparência desejada

- Tela inicial **minimalista**: logo no topo, assinatura em texto discreto e **cards grandes em grade de duas colunas**.
- Cards **brancos (ou da cor da superfície no tema escuro), com contorno fino e cantos arredondados**, sem blocos de cor preenchidos. A **cor da coleção aparece apenas no ícone circular** do card.
- Cada card representa uma **coleção** (ex.: Orquestra, Banda, Igreja, Estudos) e mostra **ícone, nome e quantidade de partituras**.
- Botão **Nova coleção** simples, de contorno, no canto superior direito.
- Ao crescer o número de coleções, a biblioteca **rola**; o limite de cards visíveis não foi definido.
- Alvos de toque de pelo menos 44 px, fáceis de acionar com dedo ou caneta.

### Interações

| Ação | Resultado esperado |
|---|---|
| Tocar no card | Abre a lista de partituras daquela coleção |
| Criar coleção | Informa nome, escolhe cor e ícone |
| Editar coleção | Altera nome, cor e ícone sem afetar PDFs |
| Excluir coleção | Remove a organização; regra de preservação/exclusão dos arquivos ainda precisa ser formalizada |
| Reorganizar | Arrastar cards para mudar a ordem (interação sugerida) |
| Pressionar e segurar | Acesso intuitivo à edição (interação sugerida) |

**Personalização dos cards** e liberdade de criar coleções são requisitos centrais; o detalhe do gesto de edição e da ordenação pode ser refinado na prototipação. A **tela de edição de coleção** ainda não foi desenhada.

## 4. Lista de partituras

Ao abrir uma coleção:

- Cabeçalho com **voltar**, botão **Importar PDFs** (um ou vários arquivos), **título da coleção** com a quantidade de partituras e **barra de pesquisa**.
- Lista **sem cartões**: linhas separadas por divisórias finas, com o **nome da partitura** e, abaixo, em texto simples, **as coleções às quais ela pertence** (ex.: "Orquestra · Igreja").
- Cada linha tem um ícone de **renomear** (altera só o nome mostrado no app).
- Uma mesma partitura pode estar em **mais de uma coleção**, sem duplicação.
- Tocar na linha abre o arquivo.
- **Seleção múltipla** por **pressionar e segurar**, inclusive de **coleções diferentes**. Há uma dica curta na tela: "Segure uma partitura para selecionar, mesmo de coleções diferentes."
- Item selecionado: **fundo suave e marca de confirmação** (check).
- Com itens selecionados, aparece uma **barra flutuante escura na parte inferior**, com a contagem ("2 selecionadas") e as ações **Limpar** e **Abrir em abas**.
- Ordenação e eventuais filtros são melhorias sugeridas; ainda não houve definição de opções específicas.

## 5. Leitor de partitura

### Navegação e visualização

- O PDF ocupa **toda a área útil possível** do tablet, com margens mínimas.
- Suporte a **várias partituras abertas em abas**, inspiradas nas abas do navegador, mas em estilo minimalista: **texto com sublinhado na aba ativa** e botão de fechar em cada aba.
- O **`+`** abre um seletor de partituras de **todas as coleções** para acrescentar uma nova aba. (A tela desse seletor ainda não foi desenhada.)
- É possível mudar de aba sem voltar à biblioteca e fechar abas individualmente.
- Zoom e navegação pelas páginas são necessidades implícitas de um leitor de PDF para tablet.
- O cabeçalho do leitor tem apenas: **ícone compacto de início**, abas, `+` e o controle de recolher abas. **Não há título grande da partitura nem botão grande "Voltar à biblioteca".**

### Barra de ferramentas

- **Barra flutuante e arredondada na parte inferior**, em estilo claro (ou escuro no tema escuro), contendo, nesta ordem: **caneta, grifador, borracha**, **paleta de cores**, **desfazer**, **exportar PDF** e o controle de **recolher**.
- Não existe botão "Selecionar" nem botão "Salvar".

### Interface recolhível

- **Abas recolhíveis** e **barra de ferramentas recolhível** de forma independente, pelos respectivos controles.
- **Modo focado**: oculta abas e ferramentas e **mostra o mínimo possível de ícones**. Resta apenas **uma pequena aba discreta no centro do topo**, que reabre **abas e ferramentas juntas**. O ícone de início fica acessível na barra de abas depois que ela é reaberta.
- Nenhum botão flutuante permanece sobre a partitura no modo focado.
- Evitar que barras, títulos e menus roubem espaço da partitura.

## 6. Anotações com caneta digital

### Ferramentas obrigatórias

| Ferramenta | Comportamento |
|---|---|
| **Caneta** | Desenhar rabiscos, sinais, dedilhados e observações sobre a partitura |
| **Grifador** | Destacar visualmente trechos sem ocultar a leitura |
| **Borracha** | Apagar rabiscos/grifos da camada de anotações, não o conteúdo original do PDF |
| **Desfazer (undo)** | Reverter a última operação de anotação, inclusive apagamentos |

### Salvamento

- **Tudo o que é anotado é salvo automaticamente**, ao concluir cada traço, cada apagamento e cada desfazer.
- **Não existe botão de salvar.** O usuário não precisa lembrar de gravar nada.
- Nenhum indicador de "salvo" aparece na tela por padrão, para manter o visual limpo. Um sinal discreto pode ser avaliado depois (ver seção 11).

### Paleta de cores

- **Preto** — padrão inicial (`#000000`).
- **Vermelho** — `#E53935`.
- **Amarelo** — `#FACC15`.
- **Verde** — `#22A559`.
- **Roxo** — `#6D3BD2`.
- **Seletor RGB** — qualquer outra cor escolhida pelo usuário.

A paleta de anotação é **a mesma nos temas claro e escuro**.

**Uso da caneta:** a intenção é desenhar com a caneta e usar o dedo para navegação/zoom, com proteção contra toques acidentais da palma da mão sempre que o tablet permitir.

## 7. Preservação do original e exportação

Este é um requisito de negócio **não negociável**:

1. Renomear uma partitura **não renomeia nem sobrescreve** o PDF original; altera somente o nome apresentado no Notivo.
2. Escrever, grifar, apagar e desfazer **não alteram os bytes** do PDF original; as anotações são guardadas pelo aplicativo.
3. Quando o usuário quiser um arquivo efetivamente modificado, deve poder escolher **Exportar PDF**.
4. A exportação gera uma **nova cópia**, com o **nome escolhido no aplicativo** e as **anotações incorporadas**.
5. É possível continuar acessando o documento original sem perder a organização do app.

## 8. Identidade visual — manual de marca Notivo 1.0 (revisado)

O arquivo de referência é `notivo-manual-de-marca.html` e deve prevalecer sobre convenções visuais genéricas.

### Conceito da marca

O **N** é desenhado como forma musical: duas hastes com cabeças de nota na base, ligadas por uma diagonal, como uma barra de colcheias. O símbolo substitui visualmente a primeira letra da palavra **Notivo**. A marca é acolhedora, legível e minimalista.

### Símbolo

- O N-nota é **um único contorno contínuo**, sem peças sobrepostas.
- As hastes saem **rentes ao ponto mais à direita de cada cabeça**.
- **Todos os cantos internos são arredondados** (haste com cabeça, haste com diagonal, diagonal com a haste direita), sem emendas ou calombos visíveis.

### Logo horizontal

- Composta pelo símbolo (N) seguido de **"otivo"** em **Poppins Medium**.
- A **base das cabeças de nota fica na linha de base do texto**, e o **topo das hastes acompanha a altura das maiúsculas**.
- Versões: **clara** (símbolo em violeta, texto em roxo escuro), **escura** (símbolo em lavanda, texto claro), **monocromática branca sobre violeta** e **monocromática em roxo escuro** para impressão a uma cor.

### Ícone do aplicativo

- **Somente o símbolo**, centralizado em quadrado de cantos arredondados.
- O símbolo é centralizado **opticamente** (peso visual), e não pela caixa geométrica, e ocupa pouco mais da metade da largura do quadrado.
- Variações: principal (violeta), escura e clara.

### Área de proteção e tamanhos mínimos

- Área de proteção: **metade da altura do N** em todos os lados.
- Tamanho mínimo proposto: **64 px de largura** para a logo e **24 px** para o ícone. *(Valores propostos, a confirmar.)*

### Paleta oficial

| Nome | Hex | Uso |
|---|---|---|
| Violeta Notivo | `#6D3BD2` | Principal, botões e marca |
| Noite | `#2E1A6B` | Títulos e fundos escuros |
| Violeta claro | `#8A5CE8` | Estados e destaques |
| Lavanda | `#C9B6F5` | Símbolo no fundo escuro e apoio |
| Névoa | `#F4EFFC` | Fundos e áreas de apoio |
| Tinta | `#1F1340` | Textos |

### Tema escuro (derivado da paleta oficial)

| Função | Claro | Escuro |
|---|---|---|
| Fundo | `#FFFFFF` | `#14102A` |
| Superfície de cards e barras | `#FFFFFF` | `#1B1636` |
| Fundo suave (busca, seleção, área de leitura) | `#F4EFFC` | `#1F1940` |
| Texto principal | `#2E1A6B` / `#1F1340` | `#F1EBFF` |
| Texto secundário | `#5B4D85` | `#B3A6D9` |
| Divisórias | `#E6DDF7` | `#2E2552` |
| Destaque (links, botões de contorno) | `#6D3BD2` | `#B79CF0` |
| Símbolo da logo | `#6D3BD2` | `#C9B6F5` |

- A **página da partitura permanece branca nos dois temas**, para preservar a fidelidade ao papel e o contraste das anotações. Uma versão com página invertida está em aberto (seção 11).
- A barra de seleção e os elementos escuros sobre a partitura mantêm a cor **Noite** nos dois temas.

### Tipografia

- **Poppins** (400/500/600) para logo, interface, títulos e botões.
- **Source Serif 4** (400/600) para textos longos e editoriais.

### Ícones

- Biblioteca **Lucide** (traço de 2 px e pontas arredondadas).
- Ícones usados nas telas de referência: `house`, `plus`, `search`, `pen`, `highlighter`, `eraser`, `undo-2`, `download`, `x`, `chevron-up`, `chevron-down`, `chevron-left`, `check`, `pencil`, `music`, `drum`, `church`, `book-open`.

### Uso do logo

- Preservar a forma original do **N musical**; não usar um "N" comum junto ao símbolo.
- Não distorcer, girar, trocar a fonte da marca nem aplicar cores fora da paleta oficial.
- Não usar sobre fundos com pouco contraste.
- Ícone do aplicativo: **somente o símbolo N**.

**Observação:** os cards podem ter **cores personalizáveis pelo usuário**; essa flexibilidade não implica mudar as cores oficiais do logotipo.

## 9. Telas de referência

As telas foram desenhadas em um **canvas de design estático** (artifact), em **retrato (834 × 1194 px)**, com versões **clara e escura** de cada uma:

1. **Biblioteca** — logo, assinatura, botão Nova coleção e cards em duas colunas.
2. **Lista de partituras com seleção múltipla** — cabeçalho, busca, linhas com divisórias, barra "Abrir em abas".
3. **Leitor com abas e ferramentas** — abas em texto, partitura em página inteira, barra flutuante de ferramentas.
4. **Leitor em modo focado** — somente a partitura e uma aba discreta no topo.

Link do canvas: https://claude.ai/artifact/AVUnh53kspzWpKi72FFDqA

**Natureza deste material:** é referência de design, **sem interação**. Contagens, nomes de peças e a partitura exibida são **ilustrativos**. Como ainda não existe PDF real nas telas, a pauta é um desenho estilizado.

**Ainda não desenhadas:** edição de coleção, seletor do botão `+`, fluxo de exportação, layouts em paisagem e versão para celular.

## 10. Priorização de funcionalidades

### Essenciais / MVP

- Biblioteca de cards personalizáveis.
- Criar, editar e acessar coleções.
- Importação e lista pesquisável de PDFs.
- Renomear somente no app.
- Mesma partitura em várias coleções.
- Seleção múltipla e abrir partituras de coleções diferentes em abas.
- Leitor de PDF com barra de abas e botão `+`.
- Ferramentas de anotação com caneta, grifador, borracha e paleta definida.
- **Salvamento automático** das anotações e desfazer.
- Recolhimento de abas e ferramentas; modo focado com mínimo de ícones; ausência de título/cabeçalho invasivo.
- Armazenamento local/offline preservando o original.
- Exportação de nova versão do PDF anotado/renomeado.
- Backup/restauração local da biblioteca (recomendado como proteção essencial dos dados).
- **Tema claro e escuro** (presente nas telas de referência; a prioridade no MVP deve ser confirmada).

### Evoluções futuras discutidas, sem compromisso no MVP

- Virar páginas com pedal Bluetooth.
- Sincronização entre vários dispositivos/nuvem.
- Recursos extras de ordenação e filtros.
- Redo persistente e outras ferramentas avançadas de anotação.

## 11. Critérios de aceite de negócio

**Cenário 1 — organizar:** o músico cria "Orquestra", define ícone/cor, importa duas partituras, edita o nome de uma e encontra ambas na busca.

**Cenário 2 — compartilhar entre cards:** adiciona uma partitura de "Orquestra" também em "Igreja"; a partitura continua sendo um único documento lógico, inclusive nas anotações, e a linha mostra as duas coleções.

**Cenário 3 — ensaio:** seleciona músicas de "Banda" e "Igreja", abre todas em abas, alterna entre elas e usa `+` para acrescentar outra.

**Cenário 4 — escrita:** escolhe vermelho, escreve com a caneta, usa a borracha, desfaz a ação e fecha a partitura **sem precisar salvar**; ao reabrir, os rabiscos permanecem.

**Cenário 5 — leitura focada:** recolhe abas e ferramentas, vê praticamente só a partitura com uma única aba discreta no topo e restaura os controles com um toque, sem sair da partitura.

**Cenário 6 — exportação:** renomeia e grifa o documento, exporta nova cópia PDF com ambas as mudanças; o PDF original permanece intacto.

**Cenário 7 — tema:** alterna entre tema claro e escuro; todos os textos permanecem legíveis, a partitura continua branca e as cores de anotação não mudam.

## 12. Situação atual, decisões em aberto e próximos passos

- Há um **protótipo HTML** interativo (`notivo_prototipo.html`) anterior a esta versão. A preferência declarada é que alterações do protótipo atualizem **somente esse HTML**. O **canvas de telas** foi criado a pedido explícito, como referência de design, e o **manual de marca em HTML** também.
- As decisões desta versão (retrato, minimalismo, Lucide, tema escuro, sem botão salvar, modo focado mínimo) estão no canvas. **O protótipo HTML ainda precisa ser alinhado a elas**, caso continue sendo mantido.
- O protótipo **não é ainda o app mobile definitivo**. Persistência robusta de PDFs, uso confiável de caneta real e **exportação de PDF anotado** continuam etapas de implementação.

### Decisões em aberto

- Plataformas e hardware-alvo.
- Regras de exclusão de coleção versus exclusão definitiva da partitura.
- Regras de backup e exportação.
- Layouts em paisagem e versão para celular.
- Tema: seguir o sistema, escolha manual ou ambos.
- Página da partitura invertida no tema escuro (hoje fica branca).
- Indicador discreto de "salvo" (hoje não há).
- No modo focado, um único controle reabre abas e ferramentas; avaliar se vale separar em dois.
- Telas faltantes: edição de coleção, seletor do `+` e fluxo de exportação.
- Confirmação dos tamanhos mínimos e da área de proteção da logo.
