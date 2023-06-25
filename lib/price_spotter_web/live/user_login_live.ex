defmodule PriceSpotterWeb.UserLoginLive do
  use PriceSpotterWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        <%= gettext("Sign in to account") %>
        <:subtitle>
          <%= gettext("Don't have an account?") %>
          <.link navigate={~p"/users/register"} class="font-semibold text-brand hover:underline">
            <%= gettext("Sign up") %>
          </.link>
        </:subtitle>
      </.header>

      <.simple_form for={@form} id="login_form" action={~p"/users/log_in"} phx-update="ignore">
        <.input field={@form[:email]} type="email" label={gettext("Email")} required />
        <.input field={@form[:password]} type="password" label={gettext("Password")} required />

        <:actions>
          <.input field={@form[:remember_me]} type="checkbox" label={gettext("Keep me logged in")} />
          <.link href={~p"/users/reset_password"} class="text-sm font-semibold">
            <%= gettext("Forgot your password?") %>
          </.link>
        </:actions>
        <:actions>
          <.button phx-disable-with={gettext("Signing in...")} class="w-full">
            <%= gettext("Sign in") %> <span aria-hidden="true">→</span>
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email = live_flash(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")

    {:ok,
     socket
     |> assign(:page_title, gettext("Log in"))
     |> assign(form: form), temporary_assigns: [form: form]}
  end
end
