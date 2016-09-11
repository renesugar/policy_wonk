defmodule PolicyWonk.Loader do
  use Behaviour

@moduledoc """

To keep resource loading logic organized, PolicyWonk uses `load_resource` functions that you create either in your controllers, router, or a central location.

A `load_resource` function attempts to load a given resource into memory and returns that loaded resource

    def load_resource( _conn, :user, %{"id" => user_id} ) do
      case Repo.get(Account.User, user_id) do
        nil ->  {:error, "User not found"}
        user -> {:ok, user}
      end
    end
 
The *only* way to indicate success from a load_resource function is to return a tuple such as `{:ok, loaded_resource}`.

To gracefully handle a load error, return a tuple such as `{:error, error_data}` where error_data is whatever you want to indicate what went wrong. The error_data field will be passed into your load_error function.

The idea is that you define multiple policy functions and use Elixir’s pattern matching to find the right one. If you use a tuple (or a map) as the second parameter, then you can have more complex calls to your loaders.

The first parameter is the current `%Plug.Conn{}` and the last is the conn’s `params` field. You are not expected to directly manipulate the conn here. Instead, the plug adds your resource to the conn’s assigns field for you. See [Sychronous vs. Asynchronous Loading](#module-sychronous-vs-asynchronous-loading) for more information.

## Loader Failures

When a loader returns a tuple such as `{:error, error_data}`, that is a loader failure. 

The LoadResource will then cease attempting to load other resources and call your `load_error(conn, error_data)` function. The `error_data` parameter is the data you specified when you returned the error from your `load_resource` function.

    def load_error(conn, err_data) do
      conn
      |> put_status(404)
      |> put_view(MyApp.ErrorView)
      |> render("404.html")
      |> halt()
    end

The `load_error` function works just like a regular plug function. It takes a `conn`, and whatever was returned from the loader. You can manipulate the `conn` however you want to respond to that error. Then return the `conn`.

Unlike handling a policy error, `halt(conn)` is not called for you. If you want the resource load failure to halt the plug chain, make sure to call `halt(conn)` in your load_error function.

## Sychronous vs. Asynchronous Loading

When you invoke the `PolicyWonk.LoadResource` plug, you can pass in a single resource definition or a list of them.

    plug PolicyWonk.LoadResource, [:thing1, :thing2]


If you set `load_async` to `true` in the `config` parameters, or pass it in directly, then `PolicyWonk.LoadResource` will attempt to load all the resources in the list at the same time.

Coordinating these loads is why your `load_resource` function returns the resource in a tuple instead of directly adding it to the conn’s assign field.

If you need the fields loaded synchronously, either set the flag to false, or load the resources in seperate plug invocations.

    plug PolicyWonk.LoadResource, :thing1
    plug PolicyWonk.LoadResource, :thing2

## Loader Locations

When a load_resource function is used in a single controller, then it should be defined on that controller. Same for the router. 

If a load_resource function is used in multiple locations, then you should define it in a central loaders file that you refer to in your configuration data.

In general, when you invoke the `PolicyWonk.LoadResource` plug, it detects if the incoming `conn` is being processed by a Phoenix controller or router. It looks in the appropriate controller or router for a matching load_resource function first. If it doesn’t find one, it then looks in loader module specified in the configuration block.

This creates a form of loader inheritance/polymorphism. The controller (or router) calling the plug always has the authoritative say in what load_resource function to use.

You can also specify the loader’s module when you invoke the `PolicyWonk.LoadResource` plug. This will be the only module the plug looks for a `load_resource` function in.

"""

  @doc """
  Define a loader.

  ## parameters
  * `conn`, the current conn in the plug chain. For informational purposes.
  * `loader`, The loader you requested with invoking the plug
  * `params`, the `params` field from the current `conn`. Passed in as a convenience. Useful for parsing and matching against.
          def load_resource( _conn, :user, %{"id" => user_id} ) do
            case Repo.get(Account.User, user_id) do
              nil ->  {:error, "User not found"}
              user -> {:ok, user}
            end
          end

  ## Returns
  * `{:ok, resource}` If the load succeeds, return the loaded resource in a tuple with :ok
  * `{:error, error_data}` If the load fails, return any error data you want with :error in a tuple
  """
  defcallback load_resource(Plug.Conn.t, atom, Map.t) :: {:ok, any} | {:error, any}

  @doc """
  Define a load error handler.

  ## parameters
  * `conn`, the current conn in the plug chain. Transform this to handle the error.
  * `error_data`, the `error_data` returned from your load_resource function.

          def load_error(conn, err_data) do
            conn
            |> put_status(404)
            |> put_view(MyApp.ErrorView)
            |> render("404.html")
            |> halt()
          end
    
  ## Returns
  * `conn`, return the transformed `conn`, which will be used in the plug chain..
  """
  defcallback load_error(Plug.Conn.t, any) :: Plug.Conn.t

end