defmodule StamperWeb.Router do
  use StamperWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", StamperWeb do
    pipe_through :api
    post "/stamps", StampController, :stamp_process
  end
end
