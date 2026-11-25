# Kuanto (Gastos Flutter)

Aplicativo Flutter offline-first de finanças pessoais e do casal, integrado à API REST do `gastos-backend` (Dart Shelf + PostgreSQL).

## 🏗️ Arquitetura

- **State Management:** Riverpod (`flutter_riverpod`)
- **Navegação:** `go_router`
- **Rede:** `dio` (TLS validado pelo sistema, refresh token single-flight, sem logs de corpos sensíveis)
- **Banco Local:** Drift / SQLite (`schemaVersion` **13**, armazenamento em texto puro compatível com backup/sync)
- **Armazenamento Seguro:** `flutter_secure_storage` (tokens JWT e credenciais) + `SharedPreferences` (tema e cor principal persistidos)
- **Modelos:** `freezed` + `json_serializable`
- **Gráficos:** `fl_chart`
- **Tema:** Material 3 (Claro / Escuro / Sistema + paleta configurável)

## 📁 Estrutura do Projeto

```text
lib/
├── core/
│   ├── api/            # DioClient, endpoints e provedores HTTP
│   ├── database/       # AppDatabase (Drift schema v13)
│   ├── notifications/  # Permissões e cliente local de notificações
│   ├── router/         # GoRouter + guarda de autenticação
│   ├── storage/        # Configuração de armazenamento seguro
│   ├── sync/           # SyncService offline-first + SyncProvider
│   ├── theme/          # Temas Material 3 e persistência de cor/modo
│   ├── utils/          # Formatadores BR (R$, datas, validadores)
│   └── widgets/        # Widgets compartilhados
└── features/
    ├── auth/           # Login, cadastro, modo convidado, recuperação de senha
    ├── categories/     # Categorias de entradas e saídas + ícones
    ├── credit_cards/   # Cartões, ciclos de fatura, fechamento e status paga
    ├── dashboard/      # Resumo financeiro, sparkline e drawer de configurações
    ├── goals/          # Metas financeiras sincronizáveis
    ├── navigation/     # Shell principal com 4 abas (LazyIndexedStack)
    ├── planning/       # Orçamento mensal (individual e casal) + alertas
    ├── receipts/       # Leitor QR Code NFC-e (SEFAZ-PR), revisão e cupom fiscal digital
    ├── recurring/      # Recorrências com geração automática ao abrir e botão "Lançar agora"
    ├── reports/        # Gráficos interativos por categoria, evolução e pagamento
    ├── settings/       # Configurações de notificações, seletor de cores e backup JSON
    ├── sharing/        # Conexão e sincronização com parceiro
    └── transactions/   # CRUD de lançamentos, parcelas, lembretes e exportação CSV
```

## ✅ Funcionalidades Implementadas

- **Autenticação e Segurança:** Login, cadastro, modo convidado local, JWT com access/refresh tokens persistidos em `flutter_secure_storage` e fluxo de recuperação de senha (`forgot/reset-password`).
- **Offline-First e Sincronização Completa (`SyncService`):** Categorias, subcategorias, transações, cupons fiscais (com itens e descontos), cartões de crédito, faturas/status de pagamento (`appSettings`), recorrências, planos de orçamento, alertas (`budgetAlerts`) e metas (`goals`), com *tombstones* para exclusões offline.
- **Cupom Fiscal (NFC-e / SEFAZ-PR):** Leitura via câmera (`mobile_scanner`) ou link manual, extração completa dos produtos e descontos por item, revisão editável e tela "Detalhes da Compra" no estilo DANFE NFC-e digital.
- **Transações Recorrentes:** Cadastro por frequência (`daily`, `weekly`, `monthly`, `yearly`), lembretes locais, geração idempotente automática na inicialização/restauração (`RecurringGeneratorService`) e opção manual **"Lançar agora"**.
- **Cartões de Crédito e Faturas:** Controle de limite, ciclo por dia de fechamento, valor manual de fatura, marcação de fatura paga (sincronizada) e previsão de faturas futuras.
- **Planejamento e Metas:** Orçamento individual e de casal com cálculo em tempo real, notificações locais por percentual (80%, 90%, 100%) e acompanhamento de metas.
- **Relatórios e Exportação:** Gráficos com `fl_chart`, filtro de período, exportação das transações em **CSV** (padrão Excel `pt-BR`, com nome do cartão) e **Backup e restauração em JSON** completo (com compartilhamento ou cópia local).

## 🚀 Como Executar

### Pré-requisitos
- Flutter SDK `3.24+` / Dart `3.4+`
- Backend `gastos-backend` rodando (local na porta `8082` ou produção configurada em `ApiEndpoints.baseUrl`)

### Geração de Código e Testes

```bash
# Instalar dependências
flutter pub get

# Gerar código (Freezed, JSON Serializable, Drift)
dart run build_runner build --delete-conflicting-outputs

# Analisar código
flutter analyze --no-fatal-infos --no-fatal-warnings

# Executar suíte de testes
flutter test

# Executar o app
flutter run
```

## 🔄 CI/CD

- **Flutter CI** (`.github/workflows/flutter_ci.yml`): executa `flutter pub get`, `build_runner`, `flutter analyze`, `flutter test` e gera o APK `release` assinado automaticamente nos pushes em `main` e `develop`.
