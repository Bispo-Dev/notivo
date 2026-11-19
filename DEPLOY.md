# Deploy

O Notivo é publicado em duas partes, ambas gratuitas:

| Parte | Onde | Endereço |
|-------|------|----------|
| Página de download (`site/`) | Cloudflare Workers | `https://notivo.<conta>.workers.dev` (ou domínio próprio) |
| APK | GitHub Releases | `https://github.com/Bispo-Dev/notivo/releases/latest/download/notivo.apk` |

O site sempre aponta para `releases/latest/download/notivo.apk`, então publicar uma versão nova não exige mexer no site, exceto no número da versão exibido.

## Antes da primeira publicação

1. **Repositório público.** O download das Releases só funciona sem login se o repositório for público. Se o código precisar ficar privado, crie um repositório público só para as Releases e troque o link em `site/index.html` (dois lugares).
2. **Chave de assinatura.** `app/android/key.properties` (fora do git) aponta para o keystore com `storeFile`, `storePassword`, `keyAlias` e `keyPassword`. Faça backup do keystore e das senhas fora do computador: sem a mesma chave, quem já instalou não consegue atualizar. Se o app também for para a Play Store, use essa mesma chave como chave de upload e decida a assinatura antes de distribuir o primeiro APK.
3. **Cloudflare Workers** (uma vez; o `wrangler.jsonc` da raiz publica a pasta `site/` como site estático):
   1. Painel da Cloudflare › *Workers & Pages* › *Create* › *Import a repository*.
   2. Escolha o repositório e a branch `main`.
   3. *Build command*: vazio. *Deploy command*: `npx wrangler deploy`. *API token*: deixe a Cloudflare criar um novo.
   4. *Deploy*. Daí em diante, cada push na `main` publica o site sozinho.
   5. Domínio próprio (opcional): *Settings* › *Domains & Routes* › *Custom domain*. O domínio precisa estar com o DNS na Cloudflare.

## Publicar uma versão

1. **Versão.** Suba `version` em `app/pubspec.yaml`: o nome e o número depois do `+` (ex.: `1.1.0+2`). O número depois do `+` precisa sempre crescer, senão o Android recusa a atualização.
2. **Site.** Atualize “Versão x.y.z” em `site/index.html`, no texto e no link da tag (`releases/tag/vx.y.z`).
3. **Checagens.** Rode as ferramentas de `app/tool/` descritas em `app/README.md`.
4. **APK.** Na raiz:

   ```powershell
   .\app\instalar-android.ps1 -Release
   ```

   Gera em `app\build\release\`, assinados com a chave de release e cada um com seu `.sha256`:
   - `notivo.apk`: arm64, praticamente todo celular e tablet atual. É o que o site oferece.
   - `notivo-32bits.apk`: só para celulares Android 32 bits antigos. Não aparece no site; mande o link direto a quem o `notivo.apk` der "app incompatível": `https://github.com/Bispo-Dev/notivo/releases/latest/download/notivo-32bits.apk`.

   O script para se `key.properties` não existir.
5. **Teste.** Instale o `notivo.apk` num aparelho por cima da versão anterior e confira que atualiza sem perder a biblioteca.
6. **Commit e tag.**

   ```powershell
   git commit -am "Versão 1.1.0"
   git tag v1.1.0
   git push origin main --tags
   ```

7. **Release.** No GitHub: *Releases* › *Draft a new release* › tag `v1.1.0`, título `Notivo 1.1.0`, as novidades em poucas linhas, e anexe os quatro arquivos de `app\build\release\` (`notivo.apk`, `notivo-32bits.apk` e os dois `.sha256`). Os nomes precisam ser exatamente esses. Publique como *Latest release*.
   Com o GitHub CLI instalado, o mesmo passo é:

   ```powershell
   gh release create v1.1.0 (Get-ChildItem app\build\release\notivo*) --title "Notivo 1.1.0" --notes "..."
   ```

8. **Conferir.** Abra o site, toque em “Baixar o APK” e veja se baixa a versão nova.

## Limites conhecidos

- Não há APK para x86/x86_64 (emuladores e alguns Chromebooks). O build release está sem R8 (veja `app/android/app/build.gradle.kts`), o que deixa cada APK alguns MB maior.
- Fora da Play Store não há atualização automática: o usuário baixa a versão nova pelo site.
- O Android pede para liberar a instalação de fontes desconhecidas, e o Play Protect pode mostrar um aviso na primeira instalação.
