# Notivo — Arquitetura técnica

> Versão 1.1, atualizada em 10/11/2026. Consolidação das decisões e propostas discutidas até esta data. **Distingue o protótipo HTML atual da arquitetura pretendida para o aplicativo final.**

## Alterações desta versão

- **Salvamento automático é o único mecanismo de gravação das anotações**; o botão "Salvar rabiscos" foi removido do leitor.
- **Telas de referência** em canvas de design: **retrato**, **minimalistas**, ícones **Lucide**, **tema claro e escuro**.
- **Modo focado** com o mínimo de ícones: uma única aba discreta no topo reabre abas e ferramentas.
- Novos componentes e requisitos: **tema (design tokens)**, **ícones** e **regras de salvamento por traço**.
- Seção de **design tokens** (anexo) e novos **pontos em aberto**.

## 1. Visão técnica

O **Notivo** é um organizador e leitor de partituras em PDF, voltado prioritariamente a **tablets com caneta digital**. A experiência deve ser simples, rápida e funcionar **offline**, com armazenamento local. A edição de nomes e anotações é **não destrutiva**: o PDF original fica intacto; o aplicativo mantém metadados e uma camada de anotações própria, podendo gerar uma cópia exportada com as alterações. A interface tem **tema claro e escuro** e é desenhada primeiro em **retrato**.

## 2. Decisões de plataforma

| Aspecto | Direção | Situação |
|---|---|---|
| Protótipo de telas | **Um único arquivo HTML**, atualizado continuamente | Definido e existente (anterior a esta versão) |
| Referência de design | **Canvas de telas estático** (artifact), retrato 834 × 1194 px, claro e escuro | Criado a pedido explícito; não interativo |
| Manual de marca | `notivo-manual-de-marca.html` | Existente; prevalece sobre convenções genéricas |
| Produto final | **Aplicativo mobile/tablet**, não apenas uma PWA | Definido |
| Tecnologia sugerida | **Flutter/Dart** para Android e iPadOS | Proposta técnica, ainda não implementada |
| Suporte a entrada | Caneta digital; suporte a toque para navegação | Requisito |
| Rede/conta | Uso offline, sem login obrigatório ou backend no MVP | Direção proposta |
| Arquivos | PDFs armazenados localmente no dispositivo | Requisito da versão final |
| Metadados e anotações | Banco local, sugerido **SQLite** | Proposta técnica |
| Gravação de anotações | **Automática**, sem botão de salvar | Definido |
| Tema | Claro e escuro, derivados da paleta oficial | Definido nas telas; regra de seleção (sistema/manual) em aberto |
| Ícones | **Lucide** | Definido nas telas |
| Orientação | Retrato como referência; paisagem a desenhar e validar | Parcial |

A escolha entre Android, iPadOS ou suporte efetivo a ambos, assim como o modelo de caneta, não foi confirmada. **S Pen/Apple Pencil dependem do dispositivo e dos recursos disponibilizados pelo sistema operacional.**

## 3. Componentes propostos para o aplicativo final

1. **Biblioteca** — cards de coleções e sua ordenação/personalização.
2. **Gerenciador de partituras** — importação, busca, alteração de nome visível, vínculo com coleções, seleção múltipla.
3. **Sessão de leitura** — abas de partituras abertas, adição de arquivos por `+`, alternância entre abas e layout compacto.
4. **Renderizador de PDF** — visualização de páginas, zoom e rolagem, sem modificar o original.
5. **Motor de anotação** — camada de traços sobre cada página, cores, ferramenta de caneta, grifador, borracha e undo, com **gravação automática**.
6. **Persistência local** — grava PDFs, coleções, vínculos, preferências (inclusive tema), anotações e estado necessário de leitura.
7. **Exportador** — produz **um novo PDF** com nome personalizado e anotações incorporadas, mantendo o original inalterado.
8. **Backup/restauração da biblioteca** — recomendado para evitar perda por troca de tablet, limpeza de dados ou falha do aparelho.
9. **Tema e design tokens** — cores, tipografia, raios e espaçamentos centralizados, com variantes clara e escura (ver anexo).

### Tecnologias sugeridas

- **Flutter**: interface responsiva do app, navegação e interações de toque/caneta; `ThemeData` com esquemas claro e escuro para o tema.
- **CustomPainter + eventos de ponteiro**: desenho da camada de anotações e diferenciação entre caneta/dedo; suporte a pressão quando fornecido pelo dispositivo.
- **SQLite**: índices, relações e metadados; armazenar PDFs no sistema de arquivos privado do app.
- **Biblioteca Flutter de PDF a selecionar e validar**: renderização, navegação, captura do tamanho das páginas e geração/exportação de PDF. Ainda não há dependência de Flutter escolhida definitivamente.
- **Ícones Lucide**: existem pacotes da comunidade para Flutter; é preciso **escolher e validar** um deles (cobertura dos ícones usados, manutenção e licença).
- **Fontes**: Poppins e Source Serif 4, incluídas como assets do app para funcionar offline.

> **Nota histórica:** a primeira abordagem cogitada era **Angular + Tailwind + PWA + PDF.js + Dexie/IndexedDB + pdf-lib**. Ela foi substituída como direção do **produto final** pela solicitação de um aplicativo mobile com caneta. O **HTML continua sendo o único formato de prototipação solicitado**, salvo pedidos explícitos (como o canvas de telas e o manual de marca).

## 4. Modelo de dados conceitual

```text
Colecao
  id, nome, cor, icone, ordem

Partitura
  id, nomeOriginal, nomeExibicao, caminhoArquivoLocal,
  dataImportacao, outrosMetadados

ColecaoPartitura
  colecaoId, partituraId, ordemNaColecao

Anotacao
  id, partituraId, pagina, ferramenta, cor, espessura,
  opacidade, pontos/coordenadas, ordem, estado

Preferencias
  tema (claro | escuro | sistema), ...

SessaoLeitura (opcional)
  abasAbertas[], abaAtiva, abasVisiveis,
  ferramentasVisiveis, modoFocado
```

**Relação muitos-para-muitos:** uma partitura pode constar de várias coleções sem duplicar o PDF nem as anotações. Alterar seu nome exibido ou suas anotações é uma alteração lógica da mesma partitura, refletida em todas as coleções. A lista mostra, em cada linha, as coleções da partitura.

**Anotação separada:** coordenadas precisam ser relativas ao espaço da **página do PDF**, não simplesmente aos pixels da tela; isso preserva alinhamento após zoom, rotação e mudanças de tamanho. Para documentos com várias páginas, cada traço precisa registrar a página correspondente.

## 5. Arquivos e integridade

- Ao importar, preservar uma **cópia do PDF original**, sem edição em seu conteúdo.
- Renomear altera somente `nomeExibicao` no banco local, não o arquivo original.
- Anotar, grifar, apagar e desfazer alteram somente a camada de anotações local.
- Uma **exportação** cria um PDF **novo** com as anotações compostas em suas páginas e nome personalizado.
- O PDF exportado não substitui automaticamente o original.
- Exportação individual foi solicitada; exportação em lote é uma possibilidade futura, não um requisito já definido.
- Definir estratégia de backup/restauração para PDFs e banco de dados, evitando dependência exclusiva do armazenamento do aplicativo.

## 6. Entrada por caneta, gestos e salvamento

**Comportamento desejado**:

- **Caneta**: escrever, grifar e apagar conforme a ferramenta ativa.
- **Dedo**: rolar páginas, trocar de abas e aplicar zoom com dois dedos.
- Reduzir traços indesejados da palma da mão (*palm rejection*), na medida permitida por hardware e sistema.
- Ferramentas: **caneta, grifador, borracha**, sem botão "Selecionar" na barra de anotações.
- Paleta: **preto padrão** (`#000000`), vermelho (`#E53935`), amarelo (`#FACC15`), verde (`#22A559`), roxo Notivo (`#6D3BD2`) e **seletor RGB livre**. A paleta é a mesma nos dois temas.
- Suportar **desfazer (undo)** da última operação de anotação, inclusive ações da borracha.
- O comportamento de pressão, precisão e rejeição de palma deve ser testado em hardware real.

### Salvamento automático

- **Não há botão "Salvar rabiscos".** Toda alteração de anotação é gravada automaticamente.
- Proposta de implementação:
  - gravar ao **concluir cada traço** (levantar a caneta), cada **apagamento** e cada **desfazer**;
  - usar **transações no SQLite** para que uma operação seja gravada por inteiro ou não seja gravada;
  - garantir gravação também ao **trocar de aba, recolher o leitor ou enviar o app para segundo plano**.
- Nenhum indicador de "salvo" aparece por padrão. Em caso de **falha de gravação**, o app deve avisar o usuário de forma discreta (comportamento proposto, a validar).
- **Aceite técnico:** forçar o encerramento do app logo após um traço não pode causar perda desse traço.

## 7. Leitor e ocupação de tela

As partituras devem ocupar o máximo possível da tela. A visualização inclui:

- Abas minimalistas (texto com sublinhado na aba ativa), cada uma para uma partitura aberta, com botão de fechar.
- Botão **`+`** para escolher outra partitura, inclusive de outra coleção.
- Cabeçalho do leitor com apenas **ícone de início**, abas, `+` e controle de recolher abas. **Sem título e sem botão grande de "voltar à biblioteca".**
- **Barra de ferramentas flutuante** na parte inferior: caneta, grifador, borracha, paleta, desfazer, exportar PDF e recolher.
- Recolhimento **independente** da barra de abas e da barra de ferramentas pelos respectivos controles.
- **Modo focado**: recolhe as duas áreas e deixa o **mínimo de ícones**. Resta **uma única aba discreta no centro do topo** que reabre abas e ferramentas juntas. Não há botão flutuante sobre a partitura.
- O ícone de início fica acessível na barra de abas depois que ela é reaberta.
- O desenho final do cabeçalho precisa respeitar isso também na implementação mobile.
- Alvos de toque de **pelo menos 44 px**; controles com rótulo de acessibilidade.

## 8. Protótipo HTML, canvas de telas e manual

**Arquivo de trabalho:** `notivo_prototipo.html` (referência ao último arquivo entregue na conversa). A preferência declarada é **sempre atualizar esse protótipo HTML**, e não gerar outros protótipos/formatos, salvo pedido explícito. Foram feitas duas exceções explícitas nesta conversa: o **manual de marca em HTML** e o **canvas de telas**.

### Canvas de telas (referência de design)

- Quatro telas em retrato (834 × 1194 px), em versões **clara e escura**: Biblioteca; Lista de partituras com seleção múltipla; Leitor com abas e ferramentas; Leitor em modo focado.
- Link: https://claude.ai/artifact/AVUnh53kspzWpKi72FFDqA
- **Estático e sem interação.** Os dados (contagens, nomes de peças) e a partitura são ilustrativos; a pauta é um desenho estilizado, não um PDF real.
- **Ainda não desenhados:** edição de coleção, seletor do `+`, fluxo de exportação, layouts em paisagem e versão para celular.

### Implementações demonstrativas identificadas no HTML (anteriores a esta versão)

- Biblioteca com cards e editor de coleção (nome, ícone e cor).
- Listas de partituras por coleção ou todas, busca e importação de PDFs.
- Renomeação, associação entre coleções e seleção múltipla.
- Leitor com abas e seletor para adicionar partituras.
- Camada de desenho em `canvas`, caneta, grifador, borracha, paleta e seletor RGB.
- Botão de salvar rabiscos, undo e salvamento local demonstrativo.
- Recolhimento das abas, das ferramentas e modo focado, com comandos compactos.
- Identidade visual do Notivo aplicada ao HTML.

### Limitações técnicas atuais do protótipo

- **O protótipo HTML ainda não reflete as decisões desta versão**: retrato minimalista, ícones Lucide, tema escuro, remoção do botão de salvar e modo focado com um único controle. Se continuar sendo mantido, precisa ser alinhado ao canvas.
- Os dados demonstrativos são guardados em **`localStorage`**; isso **não** equivale à persistência robusta de PDFs e anotações da versão mobile.
- PDFs escolhidos são visualizados com URLs temporárias do navegador; **não são preservados de forma confiável entre sessões**.
- O HTML inclui partituras **ilustrativas** que não são PDFs reais.
- A ação de exportação demonstrativa gera **imagem PNG**, **não** um PDF anotado final.
- A camada de anotação em `canvas` sobre o documento é experimental; no produto final é preciso corrigir alinhamento em páginas reais, zoom, rolagem e rotação.
- A função do leitor no HTML chama `setHeading(...)` com nome e botão "Biblioteca", enquanto há regras CSS de modo de leitura para ocultar o cabeçalho. A intenção de produto é remover esses elementos do leitor, não apenas depender de ocultação visual.
- Não há validação documentada de rejeição de palma, precisão da caneta, desempenho em PDFs grandes ou backup completo.

## 9. Direção de evolução / critérios técnicos de aceite

**Etapa A — validar UX:** ajustar telas no canvas e, se mantido, no HTML.

**Etapa B — aplicativo Flutter:** persistência local real de PDFs e coleções, importação, busca, vínculos, abas, renderização multipágina e **tema claro/escuro**.

**Etapa C — anotações confiáveis:** precisão por página, desenho com caneta, zoom/rolagem com dedo, grifador, borracha, undo, **salvamento automático**, reabrir e preservar traços.

**Etapa D — exportação/segurança dos dados:** gerar novo PDF anotado/renomeado, backup e restauração, testes offline.

**Aceites essenciais:**

- Arquivo original é idêntico após renomear e/ou anotar.
- Depois de fechar e reabrir o app, partitura e rabiscos permanecem disponíveis, **sem nenhuma ação de salvar**.
- Encerrar o app imediatamente após um traço não perde esse traço.
- Uma partitura associada a duas coleções aparece em ambas e compartilha as mesmas anotações.
- É possível abrir várias partituras de coleções diferentes em abas.
- Ao recolher barras, a área útil da partitura aumenta sem perder acesso aos controles; no modo focado só resta uma aba discreta.
- Alternar entre tema claro e escuro mantém todos os textos legíveis, a página da partitura branca e as cores de anotação inalteradas.
- A exportação gera um novo PDF legível com o nome e as alterações esperadas.

## 10. Pontos ainda não definidos

- Plataformas-alvo exatas e modelos de tablet/caneta a validar.
- Limites de tamanho dos PDFs, organização multipágina e capacidade esperada da biblioteca.
- Regras detalhadas de exclusão de coleção versus exclusão definitiva da partitura.
- Persistência das abas abertas entre reinicializações do app.
- Undo após fechar/reabrir o leitor e eventual **redo** (foi sugerido antes, mas o pedido final explicitou undo).
- Exportação de anotações como objetos editáveis do PDF ou como camada incorporada/achatada.
- Regra do tema: seguir o sistema, escolha manual ou ambos.
- Página da partitura **invertida** no tema escuro (hoje fica branca) e, se adotada, o mapeamento das cores de anotação.
- Indicador de "salvo" e comportamento exato em falha de gravação.
- Se o modo focado deve ter **um controle** (atual) ou dois, para reabrir abas e ferramentas separadamente.
- Layouts em **paisagem** e versão para **celular**.
- Pacote de ícones Lucide para Flutter e pacote de PDF a adotar.
- Sincronização em nuvem, pedal Bluetooth e outras expansões: **fora do MVP inicial**.

## Anexo — Design tokens e ícones

### Tokens de cor

| Token | Claro | Escuro |
|---|---|---|
| `bg` | `#FFFFFF` | `#14102A` |
| `card` | `#FFFFFF` | `#1B1636` |
| `soft` | `#F4EFFC` | `#1F1940` |
| `ink` (texto base) | `#1F1340` | `#F1EBFF` |
| `tx` (títulos e ícones) | `#2E1A6B` | `#F1EBFF` |
| `tx2` (texto secundário) | `#5B4D85` | `#B3A6D9` |
| `ln` (divisórias) | `#E6DDF7` | `#2E2552` |
| `ln2` (divisórias de lista) | `#EFE9FA` | `#241D45` |
| `ln3` (contornos de botões) | `#D9CCF5` | `#3F3470` |
| `acc` (destaque) | `#6D3BD2` | `#B79CF0` |
| `act` (ferramenta ativa) | `#EDE5FB` | `#2E2552` |
| `mk` (símbolo da logo) | `#6D3BD2` | `#C9B6F5` |

Cores que **não mudam entre temas**: paleta de anotação, página da partitura (branca), barra de seleção e demais elementos escuros sobre a partitura (`#2E1A6B`), botão de confirmação e check em `#6D3BD2`.

### Tipografia

- Poppins 400/500/600 (logo, interface, títulos, botões); Source Serif 4 400/600 (textos longos e a partitura ilustrativa).

### Geometria e medidas

- Tela de referência: **834 × 1194 px** (retrato).
- Alvos de toque: **mínimo de 44 px**.
- Cards da biblioteca: raio de 20 px, contorno de 1 px, ícone circular de 52 px.
- Barra de ferramentas: pílula flutuante, 640 px de largura, 64 px de altura, a 28 px da borda inferior.

### Ícones Lucide usados

`house`, `plus`, `search`, `pen`, `highlighter`, `eraser`, `undo-2`, `download`, `x`, `chevron-up`, `chevron-down`, `chevron-left`, `check`, `pencil`, `music`, `drum`, `church`, `book-open`.
