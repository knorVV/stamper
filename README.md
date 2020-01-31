# Stamper

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Elixir](https://img.shields.io/badge/Elixir-1.11%2B-purple.svg)](https://elixir-lang.org)
[![Phoenix](https://img.shields.io/badge/Phoenix-1.4-orange.svg)](https://www.phoenixframework.org)
[![ImageMagick](https://img.shields.io/badge/ImageMagick-required-blue.svg)](https://imagemagick.org)
[![Status: Experimental](https://img.shields.io/badge/status-experimental-red.svg)](#статус-проекта)

JSON API на Elixir/Phoenix: генерирует печать по входным параметрам
и накладывает её в правый нижний угол документа.

> ⚠️ **Экспериментальный проект.** Не продакшн-код. 

## Возможности

- Принимает документ в формате PDF, JPG или PNG
- Генерирует печать на лету: ФИО клиента, дата подписания, хеш подписи
- Поддерживает два режима:
  - **с подписью** — выводит дату подписания и SHA-хеш
  - **без подписи** — выводит дату загрузки
- Накладывает печать в правый нижний угол документа
- Автоматически подбирает размер шрифта и печати под размеры документа
- Удаляет временные файлы через 10 секунд после отдачи результата

## Стек

- **Elixir** ~> 1.11
- **Phoenix** 1.4 — JSON API
- **Plug / Cowboy** — HTTP-сервер
- **ImageMagick** — генерация печати и наложение на JPG/PNG
- **Java Runtime** — наложение печати на PDF через `pdfstamp.jar`
- **`file`** — определение MIME-типа входного документа

## Требования

- Elixir 1.11+
- Erlang/OTP 20+
- ImageMagick (`convert`, `composite`, `identify`)
- Java Runtime Environment
- Утилита `file` (обычно есть в Linux/macOS)
- Репозиторий [pdfstamp](https://github.com/Crossref/pdfstamp) — собранный `pdfstamp.jar`

## Установка и запуск

### 1. Клонировать репозиторий

```bash
git clone https://github.com/knorVV/stamper.git
cd stamper
```

### 2. Установить зависимости

```bash
mix deps.get
```

### 3. Настроить локальные пути

Скопируйте шаблон и отредактируйте пути под свою систему:

```bash
cp config/local.exs.example config/local.exs
```

В файле `config/local.exs` укажите:

- `file_path` — папка для временного хранения файлов (должна существовать и быть доступной на запись)
- `java_repository_path` — путь к собранному `pdfstamp.jar`

### 4. Запустить сервер

```bash
mix phx.server
```

Сервер поднимется на **http://localhost:4020**.

## API

### `POST /api/stamps`

Накладывает печать на документ.

**Запрос** (`multipart/form-data`):

| Поле | Тип | Описание |
|---|---|---|
| `document` | файл | Документ (PDF, JPG, PNG) |
| `content` | файл (JSON) | Данные для печати |

**Формат `content` (JSON), с подписью:**

```json
{
  "last_name": "Иванов",
  "first_name": "Иван",
  "middle_name": "Иванович",
  "sign_datetime": "2026-10-14T12:00:00Z",
  "sign": "base64_or_raw_signature"
}
```

**Формат `content` (JSON), без подписи:**

```json
{
  "last_name": "Иванов",
  "first_name": "Иван",
  "middle_name": "Иванович",
  "inserted_at": "14.10.2026"
}
```

**Пример через curl:**

```bash
curl -X POST http://localhost:4020/api/stamps \
  -F "document=@file.pdf" \
  -F "content=@content.json" \
  --output result.pdf
```

**Успешный ответ:** файл со штампом. `Content-Type` соответствует формату входного документа (`application/pdf`, `image/jpeg`, `image/png`).

**Ошибки:**

| Код | Тело ответа | Когда возникает |
|---|---|---|
| 422 | `{"error": {"code": 2, "message": "Invalid input params"}}` | Не переданы `document` или `content` |
| 500 | `{"error": {"code": 1, "message": "Error stamped process"}}` | Ошибка во время обработки документа |

## Как это устроено

1. Клиент отправляет `POST /api/stamps` с двумя файлами: `document` (PDF/JPG/PNG) и `content` (JSON с данными клиента).
2. `StampController` передаёт их в `Stamper.Stamps.stamp_process/2`.
3. Модуль `Stamper.Stamps`:
   - сохраняет оба файла во временную папку с уникальным ID;
   - определяет MIME-тип документа через `file --mime-type`;
   - получает размеры через ImageMagick `identify`;
   - генерирует PNG-печать через ImageMagick `convert` (текст: «Верно. Подписано с использованием АСП.», ФИО, дата, хеш подписи);
   - **для PDF** — вызывает `java -jar pdfstamp.jar` и накладывает печать;
   - **для JPG/PNG** — накладывает через ImageMagick `composite`.
4. Готовый файл возвращается клиенту.
5. Временные файлы (документ, печать, JSON) удаляются асинхронно через 10 секунд.

### Размер печати

Размер шрифта и печати подбирается динамически:

- **Для PDF** — фиксированные значения (высота 170px, шрифт 30pt).
- **Для JPG/PNG** — пропорционально размеру документа. Коэффициенты подобраны эмпирически (см. модуль `Stamper.Stamps`).

## Структура проекта

```
lib/
├── stamper/
│   ├── application.ex          # Точка входа OTP-приложения
│   ├── stamps/
│   │   └── stamps.ex           # Бизнес-логика: генерация и наложение печати
│   └── utils.ex                # Вспомогательные функции
└── stamper_web/
    ├── endpoint.ex             # HTTP-endpoint
    ├── router.ex               # Роуты (один: POST /api/stamps)
    ├── controllers/
    │   ├── stamp_controller.ex     # Обработка запроса
    │   └── fallback_controller.ex  # Обработка ошибок
    └── views/
        └── error_view.ex       # JSON-шаблоны ошибок
```

## Что было интересного

- **Внешние процессы — узкое место.** Для PDF использую Java-инструмент 
  `pdfstamp.jar`, для JPG/PNG — ImageMagick (`convert`, `composite`, 
  `identify`). Нативная библиотека Elixir не умела нужные манипуляции 
  с PDF, поэтому пришлось вызывать внешний инструмент.
  - На каждый запрос запускается отдельный процесс ОС (`java -jar` или 
    `composite`). `:os.cmd` блокирует вызывающий Elixir-процесс, но 
    не мешает другим запросам обрабатываться параллельно — BEAM 
    справляется с этим без очередей.
  - Параллельные запросы порождают несколько внешних процессов 
    одновременно. При высокой нагрузке это создаёт конкуренцию за CPU 
    и память — и для Java, и для ImageMagick.
  - В продакшне это потребовало бы ограничения параллелизма: пул 
    воркеров или внешняя очередь (например, Oban или RabbitMQ).
  - Точных замеров под нагрузкой не проводил — это скорее направление 
    для будущей оптимизации.
- Коэффициент для расчёта ширины печати подбирал экспериментально: точной 
  формулы зависимости ширины текста от размера шрифта для ImageMagick нет, 
  поэтому значения калибровались на нескольких тестовых документах.
- Уборку временных файлов делаю через `Task.start` с задержкой 10 секунд — 
  чтобы `send_file` успел отдать файл, прежде чем его удалит.

## Статус проекта

Экспериментальный проект, был создан лет 7 назад для изучения Elixir, Phoenix и работы
с внешними инструментами (ImageMagick, Java, `file`).

Не предназначен для продакшн-использования.

## Лицензия

Распространяется под лицензией MIT. Полный текст — в файле [LICENSE](LICENSE).

Copyright (c) 2021 knorVV