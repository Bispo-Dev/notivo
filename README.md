<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="app/docs/notivo-manual-de-marca/notivo-logo-horizontal-escuro.svg">
    <img src="app/docs/notivo-manual-de-marca/notivo-logo-horizontal-claro.svg" alt="Notivo" width="320">
  </picture>
</p>

<p align="center"><strong>Suas partituras, sempre à mão.</strong><br>
App Android offline para organizar, ler e anotar partituras em PDF.</p>

<p align="center">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.47+-02569B?logo=flutter&logoColor=white">
  <img alt="Android" src="https://img.shields.io/badge/Android-offline-3DDC84?logo=android&logoColor=white">
  <img alt="SQLite" src="https://img.shields.io/badge/SQLite-local-003B57?logo=sqlite&logoColor=white">
</p>

## Recursos

- **Coleções** com nome, ícone (Lucide), cor do ícone e cor de fundo
- **Busca** que ignora maiúsculas, acentos e cedilha
- **Ordenação** por nome/número (crescente e decrescente) e por data de importação
- **Leitura em abas** com partituras de várias coleções ao mesmo tempo
- **Anotações por página** com caneta, grifador e borracha, salvas automaticamente
- **Modo palco** para tocar sem zoom, riscos ou abas fechadas sem querer
- **Exportação** do PDF anotado; o arquivo original nunca é alterado
- Tema **claro e escuro**, em **português e inglês**, sem conta e sem internet

## Como rodar

Com o [Flutter](https://docs.flutter.dev/get-started/install) instalado e um aparelho Android conectado:

```bash
cd app
flutter pub get
flutter run
```

Os detalhes do ambiente local, da instalação no aparelho e das checagens de design estão em [`app/README.md`](app/README.md).

## Estrutura

```
app/       app Flutter: código (lib/), Android, fontes, testes, docs/ e o script de instalação
site/      página de download do APK (HTML estático, mobile first)
```

## Documentação

- [Arquitetura técnica](app/docs/notivo-arquitetura.md)
- [Visão de negócio](app/docs/notivo-negocio.md)
- [Manual de marca](app/docs/notivo-manual-de-marca/notivo-manual-de-marca.html)
