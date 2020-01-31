defmodule Stamper.Stamps do
  @moduledoc """
    Модуль для проставления штампов
    Для проставления штампа на pdf файлы необходимо скачать репозиторий по
    ссылке https://github.com/Crossref/pdfstamp
    для запуска проставления штампа нужно вызвать pdfstamp.jar из скачанного репозитория pdfstamp.
    Пример path/pdfstamp.jar
    для файлов jpg, png используется imagemagick
  """

  alias Stamper.Utils

  require Logger

  @repository_path Application.compile_env(:stamper, [:local_path, :java_repository_path])
  # статичная часть штампа
  @stamp_part "convert -background transparent -fill darkblue -font AvantGarde-Book -border 10x10 -bordercolor darkblue -border 3x3 -bordercolor transparent"
  @file_dimensions_cmd "identify -format \"%wx%h\""
  @file_type_cmd "file --mime-type -b "
  @file_directory Application.compile_env(:stamper, [:local_path, :file_path])
  @vertical_height_ratio 17.8
  @horizontal_height_ratio 6.6
  @pointsize_ratio 6.7
  @pdf_symbol_width 18
  @pdf_height 170
  @pdf_pointsize 30
  @string_count 6.6

  @doc """
    В параметре content данные по клиенту и документу
    %{last_name: last_name, first_name: first_name, middle_name: middle_name, signing_date: signing_date, sign: sign}
    если отстутствует подпись и соответственно дата подписания, то вместо полей %{signing_date: signing_date, sign: sign}
    можно можно добавить upload_date: upload_date т.е. будет выглядеть так
    %{last_name: last_name, first_name: first_name, middle_name: middle_name, upload_date: upload_date}
  """
  @spec stamp_process(binary(), binary()) :: {:ok, any(), any()} | {:error, any()}
  def stamp_process(document, content) do
    Logger.info("Start stamp process")
    uid = Utils.uid(30)

    with {content, input_stamp_attrs_path} when is_map(content) <- decode_content(content, uid),
         file_path <- save_file_on_local_machine(document, uid),
         {file_type, content_type} when file_type not in [:error] <- check_file_type(file_path),
         file_dimensions = get_file_dimensions(file_path),
         stamp_path when not is_atom(stamp_path) <-
           do_stamp(file_type, content, file_dimensions, uid),
         stamped_file_path <- do_stamped_file(file_type, stamp_path, file_path, uid) do
      files = [stamped_file_path, stamp_path, file_path, input_stamp_attrs_path]
      Task.start(fn -> remove_files_from_local_machine(files) end)
      {:ok, stamped_file_path, content_type}
    else
      error ->
        Logger.error("error during stumped client document: #{inspect(error)}")
        {:error, error}
    end
  end

  defp decode_content(content, uid) do
    File.cp(content.path, "#{@file_directory}#{uid}_content.json")

    string =
      to_charlist("cat #{@file_directory}#{uid}_content.json")
      |> :os.cmd()
      |> to_string()

    {:ok, content} = Jason.decode(string)

    {content, "#{@file_directory}#{uid}_content.json"}
  end

  defp save_file_on_local_machine(document, uid) do
    file_name = modify_file_name(document.filename)
    File.copy(document.path, "#{@file_directory}#{uid}_#{file_name}")
    "#{@file_directory}#{uid}_#{file_name}"
  end

  # возвращает тип файла в виде атома
  def check_file_type(file_path) do
    string = to_charlist("#{@file_type_cmd}#{file_path}")

    cmd_response =
      execute_command(string)
      |> to_string()

    case cmd_response do
      "image/jpeg\n" ->
        {:jpeg, "image/jpeg"}

      "application/pdf\n" ->
        {:pdf, "application/pdf"}

      "image/png\n" ->
        {:png, "image/png"}

      _ ->
        :error
    end
  end

  def get_file_dimensions(file_path) do
    string = to_charlist("#{@file_dimensions_cmd} #{file_path}")

    string
    |> execute_command()
    |> List.to_string()
    |> String.split("x")
  end

  defp do_stamp(_file_type, _content, :error, _uid), do: :error

  # Создание штампа
  defp do_stamp(file_type, content, file_dimensions, uid) do
    with parameters when is_tuple(parameters) <-
           collection_stamp_parameter(file_type, content, file_dimensions),
         stamp_path <- create_stamp_by_parameter(parameters, uid) do
      stamp_path
    end
  end

  # Проставляет штамп на файле PDF
  defp do_stamped_file(:pdf, stamp_path, file_path, uid) do
    string =
      to_charlist(
        "java -jar #{@repository_path} -i #{stamp_path} -e #{uid} -l 380,30 -pp 1-20 #{file_path}"
      )

    execute_command(string)
    get_stamped_file_path(file_path, uid)
  end

  defp do_stamped_file(_file_type, stamp_path, file_path, _uid) do
    string =
      to_charlist(
        "composite -gravity southeast -geometry +50+100 #{stamp_path} #{file_path} #{file_path}"
      )

    execute_command(string)
    "#{file_path}"
  end

  defp get_stamped_file_path(file_path, uid) do
    "#{file_path}_#{uid}"
  end

  def modify_file_name(file_name) do
    file_name
    |> String.replace(" ", "_")
    |> String.replace(~r/[()]/, "")
  end

  defp collection_stamp_parameter(file_type, content, file_dimensions) do
    with client_name <- get_client_name(content),
         {sign, signing_date} <- get_sign_data(content),
         size when not is_atom(size) <-
           calculate_stamp_size(file_type, client_name, sign, file_dimensions) do
      {client_name, sign, signing_date, size}
    else
      error ->
        Logger.error(inspect(error))
    end
  end

  defp create_stamp_by_parameter(
         {client_name, sign, signing_date, {width, height, pointsize}},
         uid
       ) do
    # примерны размер для pdf 680x200 размер шрифта 30
    string =
      to_charlist(
        "#{@stamp_part} -size #{width}x#{height} -pointsize #{pointsize} label:'Верно.\n Подписано с использованием АСП.\n #{client_name}\n #{signing_date}\n #{sign}' #{@file_directory}stamp_#{uid}.png"
      )

    execute_command(string)
    "#{@file_directory}stamp_#{uid}.png"
  end

  defp get_client_name(%{
         "last_name" => last_name,
         "first_name" => first_name,
         "middle_name" => middle_name
       })
       when not is_nil(last_name) do
    "#{last_name} #{first_name} #{middle_name}"
  end

  defp get_client_name(_content) do
    Logger.error("Applicaton is not loaded")
    :error
  end

  def get_sign_data(%{"sign_datetime" => sign_datetime, "sign" => sign}) when not is_nil(sign) do
    signing_date =
      case DateTime.from_iso8601(sign_datetime) do
        {:ok, dt, _offset} ->
          dt
          |> DateTime.add(3 * 3600, :second)
          |> Calendar.strftime("%d.%m.%Y")

        {:error, reason} ->
          raise ArgumentError, "Invalid sign_datetime: #{reason}"
      end

    sign = :crypto.hash(:sha, sign) |> Base.encode16()
    {sign, signing_date}
  end

  def get_sign_data(%{"inserted_at" => upload_date}), do: {"", upload_date}

  def get_sign_data(_content), do: {"", ""}

  defp calculate_stamp_size(_file_type, _client_name, nil, _file_dimensions), do: :error

  defp calculate_stamp_size(:error, _client_name, _signing_code, _file_dimensions), do: :error

  defp calculate_stamp_size(:pdf, client_name, signing_code, _file_dimensions) do
    list = [client_name, signing_code]
    max_length = get_max_length(list)

    width = calculate_side(max_length, @pdf_symbol_width)
    {width, @pdf_height, @pdf_pointsize}
  end

  defp calculate_stamp_size(_file_type, client_name, signing_code, [width, height]) do
    list = [client_name, signing_code]
    max_length = get_max_length(list)

    pointsize = calculate_pointsize(width, height)
    width = calculate_width(max_length, pointsize)
    height = calculate_height(@string_count, pointsize)
    {width, height, pointsize}
  end

  defp calculate_stamp_size(_file_type, _client_name, _signing_code, _file_dimensions), do: :error

  defp calculate_pointsize(file_width, file_height) do
    file_width = String.to_integer(file_width)
    file_height = String.to_integer(file_height)

    relative_height = get_relative_height(file_width, file_height)
    relative_height / @pointsize_ratio
  end

  defp get_relative_height(file_width, file_height) do
    if file_width < file_height do
      calc_relative_height(file_height, @vertical_height_ratio)
    else
      calc_relative_height(file_height, @horizontal_height_ratio)
    end
  end

  defp calc_relative_height(file_height, ratio) do
    file_height / ratio
  end

  defp calculate_side(count, symbol_size) do
    # добавляется 1 символ чтобы на штампе с обеих сторон было одинаковое расстояние
    (count + 1) * symbol_size
  end

  defp calculate_height(count, symbol_size) do
    count * symbol_size
  end

  defp calculate_width(string_length, symbol_size) do
    # коэффициент Просто подобрал. Потому что устал думать
    string_length * symbol_size / 1.6
  end

  def get_max_length(list) do
    ["Подписано с использованием АСП." | list]
    |> Enum.max_by(&String.length/1)
    |> String.length()
  end

  def remove_files_from_local_machine(files) do
    :timer.sleep(10_000)

    files
    |> Enum.each(&remove_file/1)
  end

  defp remove_file(path), do: File.rm_rf(path)

  defp execute_command(string) do
    :os.cmd(string)
  end
end
