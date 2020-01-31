defmodule StamperWeb.ErrorView do
  use StamperWeb, :view

  def render("error.json", _),
    do: %{
      error: %{
        code: 1,
        message: "Error stamped process"
      }
    }

  def render("params_error.json", _),
    do: %{
      error: %{
        code: 2,
        message: "Invalid input params"
      }
    }
end
