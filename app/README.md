# Notivo para Android

App Flutter offline: importa PDFs para o armazenamento privado, organiza partituras em coleções, abre abas de toda a biblioteca, anota por página com caneta e salva automaticamente em SQLite. Exportação cria um novo PDF compartilhável; o arquivo importado permanece intacto.

## Referências visuais

As oito telas de `docs/notivo-telas.html` definem a composição de referência de 834 × 1194. `lib/design.dart` preserva essas medidas no tablet e adapta os componentes ao espaço disponível no celular, sem diminuir a interface inteira. Os controles do leitor mantêm alvos de 44 px; sua barra usa duas linhas quando necessário. A lista rola junto com o cabeçalho para comportar o teclado e telas baixas. A pasta `docs/notivo-manual-de-marca/` é a fonte oficial da identidade. `lib/brand.dart` usa os traçados dos SVGs do símbolo e da logo horizontal, incluindo as letras em curvas vetoriais. O ícone Android é gerado do SVG principal com o transform óptico e o raio originais.

Para regenerar os recursos Android a partir do ícone oficial: `node app/tool/generate_android_icon.mjs` (na raiz). Para conferir que os traçados Flutter e Android são os SVGs oficiais: `node app/tool/check_brand_sources.mjs`.

`tool/check_design.dart` renderiza biblioteca, barra de ferramentas e color picker nas larguras 320, 360, 411, 600, 834 e 914 (paisagem), verificando ausência de overflow, dimensões dos cards e áreas de toque. Também verifica as cores branca, vermelha, verde e preta e os limites do arraste no picker. No tablet, confere a posição (40, 201,8) e os cards de 369 × 300 nos dois temas. As capturas geradas ficam em `.tooling/design-ref/`. O seletor de anotações e coleções usa campo HSV de saturação/brilho, faixa de matiz arrastável e prévia da cor; em paisagem baixa, os controles ficam lado a lado. Manter um card pressionado o seleciona para remoção.

## Compilar e instalar

As ações das coleções ficam no botão de três pontos; manter cards pressionados abre a barra superior para remover vários. Remover uma coleção apaga apenas seus vínculos; PDFs e anotações continuam disponíveis em “Ver partituras” quando a biblioteca está vazia. Coleções removidas não são recriadas ao reiniciar.

A seleção de partituras é compartilhada entre a biblioteca e todas as coleções. A barra inferior permanece ao voltar e entrar em outra coleção, soma partituras distintas e abre o conjunto em abas. Todos os diálogos internos, inclusive cor, renomeação, organização e confirmação de remoção, usam bottom sheets com conteúdo rolável e ações acima do teclado.

Com a instalação local já preparada, execute na raiz em um PowerShell com permissão para iniciar processos:

```powershell
.\instalar-android.ps1
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

O APK debug é para sideload/desenvolvimento; publicação em loja requer assinatura própria. A exportação atual rasteriza cada página em até 144 dpi e achata as anotações; os traços salvos no app continuam editáveis nele.

