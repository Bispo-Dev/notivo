# Deploy

O Notivo é publicado em duas partes, ambas gratuitas:

| Parte | Onde | Endereço |
|-------|------|----------|
| Página de download (`site/`) | Cloudflare Pages | `https://notivo.pages.dev` (ou domínio próprio) |
| APK | GitHub Releases | `https://github.com/Bispo-Dev/notivo/releases/latest/download/notivo.apk` |

O site sempre aponta para `releases/latest/download/notivo.apk`, então publicar uma versão nova não exige mexer no site, exceto no número da versão exibido.

## Antes da primeira publicação

1. **Repositório público.** O download das Releases só funciona sem login se o repositório for público. Se o código precisar ficar privado, crie um repositório público só para as Releases e troque o link em `site/index.html` (dois lugares).
2. **Chave de assinatura.** `app/android/key.properties` (fora do git) aponta para o keystore com `storeFile`, `storePassword`, `keyAlias` e `keyPassword`. Faça backup do keystore e das senhas fora do computador: sem a mesma chave, quem já instalou não consegue atualizar. Se o app também for para a Play Store, use essa mesma chave como chave de upload e decida a assinatura antes de distribuir o primeiro APK.
3. **Cloudflare Pages** (uma vez):
   1. Painel da Cloudflare › *Workers & Pages* › *Create* › *Pages* › *Connect to Git*.
   2. Escolha o repositório e a branch `main`.
   3. *Framework preset*: `None`. *Build command*: vazio. *Build output directory*: `site`.
   4. *Save and Deploy*. Daí em diante, cada push na `main` publica o site sozinho.
   5. Domínio próprio (opcional): *Custom domains* no projeto do Pages.

## Publicar uma versão

1. **Versão.** Suba `version` em `app/pubspec.yaml`: o nome e o número depois do `+` (ex.: `1.1.0+2`). O número depois do `+` precisa sempre crescer, senão o Android recusa a atualização.
2. **Site.** Atualize “Versão x.y.z” em `site/index.html`.
3. **Checagens.** Rode as ferramentas de `app/tool/` descritas em `app/README.md`.
4. **APK.** Na raiz:

   ```powershell
   .\app\instalar-android.ps1 -Release
   ```

   Gera `app\build\release\notivo.apk` e `notivo.apk.sha256`, assinados com a chave de release. O script para se `key.properties` não existir.
5. **Teste.** Instale o `notivo.apk` num aparelho por cima da versão anterior e confira que atualiza sem perder a biblioteca.
6. **Commit e tag.**

   ```powershell
   git commit -am "Versão 1.1.0"
   git tag v1.1.0
   git push origin main --tags
   ```

7. **Release.** No GitHub: *Releases* › *Draft a new release* › tag `v1.1.0`, título `Notivo 1.1.0`, as novidades em poucas linhas, e anexe `notivo.apk` e `notivo.apk.sha256`. O nome do arquivo precisa ser exatamente `notivo.apk`. Publique como *Latest release*.
   Com o GitHub CLI instalado, o mesmo passo é:

   ```powershell
   gh release create v1.1.0 app\build\release\notivo.apk app\build\release\notivo.apk.sha256 --title "Notivo 1.1.0" --notes "..."
   ```

8. **Conferir.** Abra o site, toque em “Baixar o APK” e veja se baixa a versão nova.

## Limites conhecidos

- O APK tem cerca de 84 MB: é universal (todas as arquiteturas) e o build release está sem R8 (veja `app/android/app/build.gradle.kts`). As Releases aceitam até 2 GB por arquivo, então não há bloqueio, só download mais pesado.
- Fora da Play Store não há atualização automática: o usuário baixa a versão nova pelo site.
- O Android pede para liberar a instalação de fontes desconhecidas, e o Play Protect pode mostrar um aviso na primeira instalação.
