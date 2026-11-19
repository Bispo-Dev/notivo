# Notivo para Android

App Flutter offline: importa PDFs para o armazenamento privado, organiza partituras em coleções, abre abas de toda a biblioteca, anota por página com caneta e salva automaticamente em SQLite. Exportação cria um novo PDF compartilhável; o arquivo importado permanece intacto.

## Referências visuais

A composição de referência é a de um tablet em retrato, 834 × 1194. `lib/design.dart` preserva essas medidas no tablet e adapta os componentes ao espaço disponível no celular, sem diminuir a interface inteira. Os controles do leitor mantêm alvos de 44 px; sua barra usa duas linhas quando necessário. A lista rola junto com o cabeçalho para comportar o teclado e telas baixas. A pasta `app/docs/notivo-manual-de-marca/` é a fonte oficial da identidade. `lib/brand.dart` usa os traçados dos SVGs do símbolo e da logo horizontal, incluindo as letras em curvas vetoriais. O ícone Android é gerado do SVG principal com o transform óptico e o raio originais.

Para regenerar os recursos Android a partir do ícone oficial: `node app/tool/generate_android_icon.mjs` (na raiz). Para conferir que os traçados Flutter e Android são os SVGs oficiais: `node app/tool/check_brand_sources.mjs`.

`tool/check_design.dart` renderiza biblioteca, barra de ferramentas e color picker nas larguras 320, 360, 411, 600, 834 e 914 (paisagem), verificando ausência de overflow, dimensões dos cards e áreas de toque. Também verifica as cores branca, vermelha, verde e preta e os limites do arraste no picker. No tablet, confere a posição (40, 201,8) e os cards de 369 × 300 nos dois temas. As capturas geradas ficam em `.tooling/design-ref/`. O seletor de anotações e coleções usa campo HSV de saturação/brilho, faixa de matiz arrastável e prévia da cor; em paisagem baixa, os controles ficam lado a lado. Manter um card pressionado o seleciona para remoção.

## Compilar e instalar

A biblioteca tem busca em todas as coleções, “Abertas recentemente” (com a primeira página de cada partitura) e “Ver todas”. As ações das coleções ficam no botão de três pontos, também dentro da coleção; manter cards pressionados abre a barra de seleção embaixo para remover vários. Uma partitura que fica sem nenhuma coleção (ao remover a coleção, tirá-la da última coleção ou desmarcar todas) é apagada do Notivo com suas anotações; o PDF original escolhido na importação continua no aparelho. Antes de apagar, o app avisa quantas partituras serão apagadas. Coleções removidas não são recriadas ao reiniciar.

O leitor tem dois modos, escolhidos em “Páginas | Contínuo” na barra (no celular, no menu ⋯): **Páginas** (toque no terço esquerdo ou direito da tela, ou pedal Bluetooth via setas, Page Up/Down, espaço ou Enter, para virar; toque no meio mostra ou esconde as barras) e **Contínuo** (rolagem e zoom livres, para partituras que continuam na página seguinte; o pedal avança uma tela, deixando a última linha visível). O pincel aparece só com Caneta ou Grifador e guarda cor e espessura de cada ferramenta. **Modo palco** esconde as barras e trava zoom, anotações e o fechamento de abas; vira-se com toque nas bordas ou pedal, nos dois modos, e para sair é preciso segurar o selo do topo por 1 segundo. Com “Desenhar só com a caneta” ligado, o dedo rola e vira páginas enquanto a caneta desenha. Desfazer/refazer agem na última edição da partitura e levam até a página dela. Em Configurações › Backup, “Fazer backup” gera um .zip com coleções, partituras e anotações, e “Restaurar backup” substitui a biblioteca pelo conteúdo do arquivo.

A seleção de partituras é compartilhada entre a biblioteca e todas as coleções. Dentro de uma coleção, segurar uma partitura (ou tocar no círculo) entra no modo de seleção: toques passam a marcar, e a barra de seleção embaixo oferece adicionar à coleção, remover desta coleção e abrir em abas. A mesma barra aparece na biblioteca e mantém o conjunto para somar partituras de outras coleções. Remover da coleção e fechar uma aba não pedem confirmação: o aviso na parte de baixo oferece “Desfazer”. Todos os diálogos usam o mesmo bottom sheet (`AppSheet`): título com linha de apoio, conteúdo rolável e rodapé fixo com Cancelar e a ação principal nomeada (“Salvar coleção”, “Remover e apagar 3”), em vermelho quando apaga algo. Listas de ações usam `showActionSheet`. Regra da casa: a sheet nunca passa da metade da tela (alça incluída); o que não couber rola dentro dela. No tablet, tem no máximo 560 px de largura.

Com a instalação local já preparada, execute a partir da raiz em um PowerShell com permissão para iniciar processos:

```powershell
.\app\instalar-android.ps1
```

Esse comando resolve as dependências, compila, instala e abre o app no Samsung conectado. A sessão restrita do agente ainda impede o Dart de iniciar o compilador e os hooks nativos; SDK e plugins já foram preparados.

No PowerShell, a partir da raiz do projeto:

```powershell
$env:JAVA_HOME = (Resolve-Path .tooling\jdk).Path
$notivoTooling = (Resolve-Path .tooling).Path
$env:ANDROID_USER_HOME = Join-Path $notivoTooling 'android-user'
$env:GRADLE_USER_HOME = Join-Path $notivoTooling 'gradle-cache'
$env:APPDATA = Join-Path $notivoTooling 'local-appdata\Roaming'
$env:LOCALAPPDATA = Join-Path $notivoTooling 'local-appdata'
New-Item -ItemType Directory -Force $env:ANDROID_USER_HOME,$env:APPDATA | Out-Null
$env:JAVA_TOOL_OPTIONS = "-Duser.home=$env:ANDROID_USER_HOME"
$env:ANDROID_HOME = (Resolve-Path .tooling\android-sdk).Path
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:PUB_CACHE = (Resolve-Path .tooling\pub-cache).Path
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
Remove-Item Env:HTTP_PROXY,Env:HTTPS_PROXY,Env:ALL_PROXY -ErrorAction SilentlyContinue
node .setup-platform-tools.mjs
Expand-Archive .tooling\downloads\platform-tools_r37.0.1-win.zip .tooling\android-sdk -Force
$env:PATH = "$(Resolve-Path .tooling\android-sdk\platform-tools);$env:PATH"
& .tooling\android-sdk\cmdline-tools\latest\bin\sdkmanager.bat 'platforms;android-36' 'build-tools;36.0.0' 'ndk;28.2.13676358'
cd app
..\.tooling\flutter\bin\flutter.bat pub get
..\.tooling\flutter\bin\flutter.bat doctor --android-licenses
..\.tooling\flutter\bin\flutter.bat build apk --debug
..\.tooling\flutter\bin\flutter.bat install
```

O setup local baixa Flutter, Temurin JDK e Android command-line tools dos distribuidores oficiais e valida SHA-256 antes de extrair (`.setup-toolchain.mjs`). O ADB fica em Platform-Tools, baixado de Google e validado pelo checksum do repositório Android (`.setup-platform-tools.mjs`). Aceite as licenças que o SDK solicitar no terminal. Para instalar no telefone, habilite Opções do desenvolvedor e Depuração USB e aceite o aviso RSA no aparelho; `adb devices` deve mostrar `device` (e não `unauthorized`). Se não aparecer, instale o driver USB do fabricante.

O APK debug é para sideload/desenvolvimento.

## Publicar na Play Store

1. Gere a chave de upload uma única vez e guarde-a fora do repositório, com backup: `keytool -genkey -v -keystore notivo-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`.
2. Crie `app/android/key.properties` (ignorado pelo git) com `storeFile` (caminho do `.jks`, relativo a `app/android/app`), `storePassword`, `keyAlias` e `keyPassword`. Sem esse arquivo, o build de release usa a chave de debug, que a Play Store recusa.
3. Aumente `version` em `pubspec.yaml` a cada envio (o número depois do `+` é o `versionCode`).
4. Gere o pacote: `flutter build appbundle` → `build/app/outputs/bundle/release/app-release.aab`.

O app não pede permissões, não usa internet e não coleta dados: no formulário de Segurança dos dados, declare que nenhum dado é coletado ou compartilhado. A Play Store ainda exige um link de política de privacidade. Inclua capturas de celular e de tablet de 7" e 10"; o layout se adapta a ambos, em retrato e paisagem. A exportação atual rasteriza cada página em até 144 dpi e achata as anotações; os traços salvos no app continuam editáveis nele.

