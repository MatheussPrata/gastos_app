# Gastos Flutter

Aplicativo Flutter nativo para gerenciamento financeiro pessoal, consumindo a API REST do `gastos-backend`.

## 🏗️ Arquitetura

- **State Management**: Riverpod (flutter_riverpod + riverpod_annotation)
- **Routing**: go_router
- **Networking**: Dio + Retrofit
- **Database Local**: Drift (SQLite) - Offline-First
- **Secure Storage**: flutter_secure_storage
- **Models**: Freezed + json_serializable
- **Charts**: fl_chart
- **Theme**: Material 3

## 📁 Estrutura do Projeto

```
lib/
├── core/
│   ├── api/           # Dio client, interceptors, endpoints
│   ├── database/      # Drift database (app_database.dart)
│   ├── router/        # GoRouter configuration
│   ├── theme/         # Light/Dark themes (Material 3)
│   └── utils/         # Formatters, validators
├── features/
│   ├── auth/          # Autenticação (login, register, JWT)
│   ├── transactions/  # CRUD transações + estatísticas
│   ├── categories/    # Categorias e subcategorias
│   ├── recurring/     # Transações recorrentes
│   ├── shopping/      # Lista de compras
│   ├── dashboard/     # Dashboard principal + gráficos
│   └── settings/      # Configurações, backup, conta
└── main.dart
```

## 🚀 Como Executar

### Pré-requisitos
- Flutter SDK 3.19+
- Dart 3.3+
- Android Studio / VS Code
- Backend `gastos-backend` rodando na porta 8082

### Instalação
```bash
# Instalar dependências
flutter pub get

# Gerar código (freezed, json_serializable, drift, riverpod, retrofit)
dart run build_runner build --delete-conflicting-outputs

# Executar
flutter run
```

### Ambientes
| Ambiente | Base URL | Uso |
|----------|----------|-----|
| Development | `http://10.0.2.2:8082` | Android Emulator |
| Development (iOS) | `http://localhost:8082` | iOS Simulator |
| Staging | `https://staging-api.seudominio.com` | Testes |
| Production | `https://api.seudominio.com` | Release |

> **Nota**: Para Android Emulator, use `10.0.2.2` que mapeia para `localhost` da máquina host.

## 📱 Funcionalidades

### Fase 1 - Fundação ✅
- [x] Configuração do projeto Flutter
- [x] Drift Database com todas as tabelas
- [x] Dio Client com interceptors (Auth, Logging, Error)
- [x] GoRouter com guard de autenticação
- [x] Temas Material 3 (Light/Dark)
- [x] Formatters (moeda BR, datas)

### Fase 2 - Autenticação ✅
- [x] Login/Register com formulários nativos
- [x] JWT com access + refresh tokens
- [x] Interceptor automático de refresh token
- [x] SecureStorage para tokens
- [x] Esqueci senha / Redefinir senha

### Fase 3 - Transações (Próxima)
- [ ] CRUD Offline-First (Drift primeiro, depois API)
- [ ] Listagem com filtros (data, categoria, cartão)
- [ ] Formulário criar/editar
- [ ] Estatísticas mensais

### Fase 4 - Categorias & Cartões
- [ ] CRUD categorias com seed padrão
- [ ] CRUD cartões de crédito
- [ ] Seletores no formulário de transação

### Fase 5 - Recorrentes & Compras
- [ ] Transações recorrentes (frequência, dia do mês)
- [ ] Lista de compras com checkbox
- [ ] Geração de parcelas

### Fase 6 - Dashboard & Gráficos
- [ ] Saldo atual (receitas - despesas)
- [ ] Gráfico barras: gastos por categoria
- [ ] Gráfico linha: evolução mensal
- [ ] Próximas recorrentes + compras pendentes

### Fase 7 - Sync Engine & Backup
- [ ] Background sync (is_synced = false → API)
- [ ] Conflict resolution (last-write-wins)
- [ ] Google Drive backup via backend
- [ ] Indicador de status de sync

## 🔧 Configuração do Backend

O app consome a API do `gastos-backend` (Dart Shelf + PostgreSQL):

```bash
# No diretório do backend
cd gastos-backend
dart run bin/main.dart
```

Endpoints principais:
- `POST /api/auth/login` - Login
- `POST /api/auth/register` - Registro
- `POST /api/auth/refresh` - Refresh token
- `GET /api/auth/me` - Usuário atual
- `POST /api/sync` - Sincronização offline-first
- `GET /api/sync/status` - Status de sincronização

## 🎨 Cores do App

| Cor | Hex | Uso |
|-----|-----|-----|
| Primary | `#1E88E5` | Azul principal |
| Secondary | `#43A047` | Verde (receitas) |
| Tertiary | `#6750A4` | Roxo |
| Expense | `#E53935` | Vermelho (despesas) |
| Warning | `#FFB300` | Amarelo |

## 📦 Geração de Código

```bash
# Desenvolvimento (watch mode)
dart run build_runner watch --delete-conflicting-outputs

# Build único
dart run build_runner build --delete-conflicting-outputs
```

Gera automaticamente:
- `*.freezed.dart` - Immutables com copyWith
- `*.g.dart` - JSON serialization
- `*.gr.dart` - Retrofit clients
- `*.drift.dart` - Database DAOs
- Riverpod providers

## 🧪 Testes

```bash
# Unit + Widget tests
flutter test

# Integration tests
flutter test integration_test/
```

## 📋 Convenções

- **Naming**: snake_case para arquivos, PascalCase para classes
- **Commits**: Conventional Commits (`feat:`, `fix:`, `chore:`)
- **Branches**: `feat/nome-da-feature`, `fix/nome-do-bug`
- **PRs**: Um feature por PR, pequeno e focado

## 📄 Licença

Projeto privado - Todos os direitos reservados.