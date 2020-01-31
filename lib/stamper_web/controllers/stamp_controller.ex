defmodule StamperWeb.StampController do
  use StamperWeb, :controller

  alias Stamper.Stamps
  alias StamperWeb.ErrorView

  require Logger

  action_fallback StamperWeb.FallbackController

  def stamp_process(conn, %{"document" => document, "content" => content}) do
    case Stamps.stamp_process(document, content) do
      {:ok, stamped_file_path, content_type} ->
        Logger.info("Stamp process complete!")

        conn
        |> put_resp_content_type(content_type)
        |> send_file(:ok, stamped_file_path)

      error ->
        Logger.error("Error during stamp file: #{inspect(error)}")

        conn
        |> put_status(:internal_server_error)
        |> put_view(ErrorView)
        |> render("error.json")
    end
  end

  def stamp_process(conn, _params) do
    Logger.error("Invalid incoming params")

    conn
    |> put_status(:unprocessable_entity)
    |> put_view(ErrorView)
    |> render("params_error.json")
  end
end
