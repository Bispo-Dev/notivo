<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="site/assets/logo-escuro.svg">
    <img src="site/assets/logo-claro.svg" alt="Notivo" width="300">
  </picture>
</p>

<h3 align="center">Suas partituras, sempre à mão.</h3>

<p align="center">
  Organize, leia e anote partituras em PDF no celular ou no tablet.<br>
  Sem conta, sem internet, sem anúncios.
</p>

<p align="center">
  <a href="https://github.com/Bispo-Dev/notivo/releases/latest"><img alt="Versão" src="https://img.shields.io/github/v/release/Bispo-Dev/notivo?label=vers%C3%A3o&color=6d3bd2"></a>
  <img alt="Android 7+" src="https://img.shields.io/badge/Android-7%2B-3DDC84?logo=android&logoColor=white">
  <img alt="Offline" src="https://img.shields.io/badge/funciona-offline-2e1a6b">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white">
</p>

<p align="center">
  <a href="https://github.com/Bispo-Dev/notivo/releases/latest/download/notivo.apk"><strong>⬇️ Baixar o APK</strong></a>
  &nbsp;·&nbsp;
  <a href="https://notivo.bispo.dev.br/"><strong>🌐 notivo.bispo.dev.br</strong></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/Bispo-Dev/notivo/releases"><strong>📋 Novidades</strong></a>
</p>

---

## ✨ Feito para quem toca

| | |
|---|---|
| 📁 **Coleções** | Separe por igreja, banda, coral ou estudo. A mesma partitura pode estar em várias coleções. |
| 📖 **Páginas ou contínuo** | Uma página por vez, virando com toque na borda, ou todas em sequência, rolando. |
| ✏️ **Anotações** | Caneta, grifador e borracha em cada página, salvos na hora. O PDF original nunca é alterado. |
| 🎤 **Modo palco** | Trava zoom, riscos e abas durante a apresentação. A página só vira quando você quer. |
| 🦶 **Pedal Bluetooth** | Vire as páginas com o pedal nos dois modos, sem tirar as mãos do instrumento. |
| 🗂️ **Abas** | Abra partituras de várias coleções ao mesmo tempo e reordene arrastando. |
| 🔎 **Busca** | Encontra por nome, ignorando maiúsculas, acentos e cedilha. |
| 💾 **Backup** | Leve coleções, partituras e anotações para outro aparelho num único `.zip`. |
| 📤 **Exportar e receber** | Exporte o PDF anotado e abra PDFs vindos do WhatsApp, Drive ou e-mail. |
| 🌗 **Do seu jeito** | Tema claro, escuro ou do sistema, em português ou inglês. |

## 🔒 Nada sai do seu aparelho

O Notivo funciona sem internet e não coleta dados. Suas partituras ficam só no aparelho e nos backups que você fizer.

## 📲 Instale em 3 passos

1. **Baixe** o [`notivo.apk`](https://github.com/Bispo-Dev/notivo/releases/latest/download/notivo.apk) pelo celular ou tablet.
2. **Permita** a instalação, se o Android pedir.
3. **Importe** seus PDFs: crie uma coleção e toque em *Importar PDFs*.

Para atualizar, baixe a versão nova e instale por cima: suas coleções e anotações continuam no aparelho.

> **Celular antigo?** Se aparecer "app incompatível", o aparelho é de 32 bits: use o [`notivo-32bits.apk`](https://github.com/Bispo-Dev/notivo/releases/latest/download/notivo-32bits.apk).

---

## 🛠️ Para desenvolver

Com o [Flutter](https://docs.flutter.dev/get-started/install) instalado e um aparelho Android conectado:

```bash
cd app
flutter pub get
flutter run
```

| Pasta | O que tem |
|---|---|
| `app/` | App Flutter: código em `lib/`, projeto Android, fontes e ferramentas de checagem |
| `site/` | Página de download, HTML estático publicado pelo Cloudflare Workers (`wrangler.jsonc`) |

<p align="center"><sub>Desenvolvido por <a href="https://bispo.dev.br"><strong>Bispo Dev</strong></a> · © 2026 Notivo. Todos os direitos reservados.</sub></p>
