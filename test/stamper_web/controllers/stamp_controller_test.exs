defmodule StamperWeb.StampControllerTest do
  use StamperWeb.ConnCase

  alias Stamper.Stamps
  alias Stamper.Stamps.Stamp

  @create_attrs %{}
  @update_attrs %{}
  @invalid_attrs %{}

  def fixture(:stamp) do
    {:ok, stamp} = Stamps.create_stamp(@create_attrs)
    stamp
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all stamps", %{conn: conn} do
      conn = get(conn, Routes.stamp_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create stamp" do
    test "renders stamp when data is valid", %{conn: conn} do
      conn = post(conn, Routes.stamp_path(conn, :create), stamp: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.stamp_path(conn, :show, id))

      assert %{
               "id" => id
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.stamp_path(conn, :create), stamp: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update stamp" do
    setup [:create_stamp]

    test "renders stamp when data is valid", %{conn: conn, stamp: %Stamp{id: id} = stamp} do
      conn = put(conn, Routes.stamp_path(conn, :update, stamp), stamp: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.stamp_path(conn, :show, id))

      assert %{
               "id" => id
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, stamp: stamp} do
      conn = put(conn, Routes.stamp_path(conn, :update, stamp), stamp: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete stamp" do
    setup [:create_stamp]

    test "deletes chosen stamp", %{conn: conn, stamp: stamp} do
      conn = delete(conn, Routes.stamp_path(conn, :delete, stamp))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.stamp_path(conn, :show, stamp))
      end
    end
  end

  defp create_stamp(_) do
    stamp = fixture(:stamp)
    {:ok, stamp: stamp}
  end
end
