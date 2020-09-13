defmodule GamesRoomWeb.LoginLive do
  use GamesRoomWeb, :live_view

  @impl true
  def mount(_params, session, socket) do
    IO.puts("GamesRoomWeb.LoginLive.mount ---------------------------------------")
    IO.puts("session: #{inspect session}")
    {:ok, assign(socket, username: session["username"])}
  end

  @impl true
  def render(assigns) do
    IO.puts("GamesRoomWeb.LoginLive.render ---------------------------------------")
    IO.puts("username: #{assigns.username}")
    ~L"""
    <h2>Login</h2>
    <form phx-hook="SetSession">
      <label for="username">Name:</label>
      <input class="border-2 border-grey-400 rounded" type="text" id="username" name="username" value="<%= @username %>" />
    </form>
    <%= if @username do %>
      <p>Logged in as: "<%= @username %>"</p>
      <a class="text-blue-500 italic" href="../changeban">Go to Changeban</a>
    <% else %>
      <p>Not Logged in</p>
    <% end %>
    """
    end
end

# <form phx-hook="SetSession">
# <label for="username">Name:</label>
# <input class="border-2 border-grey-400 rounded" type="text" id="username" name="username" value="<%= @username %>" />
# <label for="color">Color:</label>
# <input class="border-2 border-grey-400 rounded" type="text" id="color" name="color" value="<%= @color %>" />
# <input type="button" onclick="myFunction()" value="Submit">
# </form>
# <p>Logged in as: "<%= @username %>" color: "<%= @color %>"</p>
#
