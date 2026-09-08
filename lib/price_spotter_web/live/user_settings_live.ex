defmodule PriceSpotterWeb.UserSettingsLive do
  use PriceSpotterWeb, :live_view

  alias PriceSpotter.Accounts

  def render(assigns) do
    ~H"""
    <.header class="text-center">
      <%= gettext("Account Settings") %>
      <:subtitle>
        <%= gettext("Manage your account email address and password settings") %>
      </:subtitle>
    </.header>

    <div class="space-y-12 divide-y">
      <div>
        <.simple_form
          for={@email_form}
          id="email_form"
          phx-submit="update_email"
          phx-change="validate_email"
        >
          <.input
            field={@email_form[:email]}
            type="email"
            label={gettext("Email")}
            required
          />
          <.input
            field={@email_form[:current_password]}
            name="current_password"
            id="current_password_for_email"
            type="password"
            label={gettext("Current password")}
            value={@email_form_current_password}
            required
          />
          <button type="submit" class="sr-only">
            <%= gettext("Save email") %>
          </button>
        </.simple_form>
      </div>
      <div>
        <.simple_form
          for={@password_form}
          id="password_form"
          action={~p"/users/log_in?_action=password_updated"}
          method="post"
          phx-change="validate_password"
          phx-submit="update_password"
          phx-trigger-action={@trigger_submit}
        >
          <.input
            field={@password_form[:email]}
            type="hidden"
            id="hidden_user_email"
            value={@current_email}
          />
          <.input
            field={@password_form[:password]}
            type="password"
            label={gettext("New password")}
            required
          />
          <.input
            field={@password_form[:password_confirmation]}
            type="password"
            label={gettext("Confirm new password")}
          />
          <:actions>
            <.button phx-disable-with={gettext("Changing...")}>
              <%= gettext("Save") %>
            </.button>
          </:actions>
        </.simple_form>
      </div>
    </div>

    <.modal
      id="password_confirmation_modal"
      show={@show_password_confirmation_modal}
      on_cancel={JS.push("cancel_password_confirmation")}
    >
      <div class="space-y-6">
        <div>
          <h2 class="text-lg font-semibold text-zinc-900 dark:text-zinc-100">
            <%= gettext("Confirm password change") %>
          </h2>
          <p class="mt-2 text-sm text-zinc-600 dark:text-zinc-300">
            <%= gettext("Enter your current password to apply this change.") %>
          </p>
        </div>

        <.simple_form
          for={%{}}
          id="password_confirmation_form"
          phx-submit="confirm_password_update"
        >
          <.input
            id="current_password_for_password_confirmation"
            name="current_password"
            type="password"
            label={gettext("Current password")}
            errors={@password_confirmation_errors}
            required
          />

          <:actions>
            <.button phx-disable-with={gettext("Saving...")}>
              <%= gettext("Confirm") %>
            </.button>
          </:actions>
        </.simple_form>
      </div>
    </.modal>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_user, token) do
        :ok ->
          put_flash(socket, :info, gettext("Email changed successfully."))

        :error ->
          put_flash(
            socket,
            :error,
            gettext("Email change link is invalid or it has expired.")
          )
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)

    user = socket.assigns.current_user
    email_changeset = Accounts.change_user_email(user)
    password_changeset = Accounts.change_user_password(user)

    socket =
      socket
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:pending_password_params, nil)
      |> assign(:show_password_confirmation_modal, false)
      |> assign(:password_confirmation_errors, [])
      |> assign(:trigger_submit, false)
      |> assign(:page_title, gettext("Account Settings"))

    {:ok, socket}
  end

  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    email_form =
      socket.assigns.current_user
      |> Accounts.change_user_email(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply,
     assign(socket,
       email_form: email_form,
       email_form_current_password: password
     )}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Accounts.deliver_user_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/users/settings/confirm_email/#{&1}")
        )

        info =
          gettext(
            "A link to confirm your email change has been sent to the new address."
          )

        {:noreply,
         socket
         |> put_flash(:info, info)
         |> assign(email_form_current_password: nil)}

      {:error, changeset} ->
        {:noreply,
         assign(
           socket,
           :email_form,
           to_form(Map.put(changeset, :action, :insert))
         )}
    end
  end

  def handle_event("validate_password", params, socket) do
    user_params = Map.get(params, "user", %{})

    password_form =
      socket.assigns.current_user
      |> Accounts.change_user_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply,
     socket
     |> assign(:password_form, password_form)
     |> assign(:pending_password_params, nil)
     |> assign(:show_password_confirmation_modal, false)
     |> assign(:password_confirmation_errors, [])}
  end

  def handle_event("update_password", params, socket) do
    user_params = Map.get(params, "user", %{})
    user = socket.assigns.current_user

    changeset = Accounts.change_user_password(user, user_params)

    if changeset.valid? do
      {:noreply,
       socket
       |> assign(:password_form, to_form(changeset))
       |> assign(:pending_password_params, user_params)
       |> assign(:show_password_confirmation_modal, true)
       |> assign(:password_confirmation_errors, [])}
    else
      {:noreply,
       assign(
         socket,
         :password_form,
         to_form(Map.put(changeset, :action, :validate))
       )}
    end
  end

  def handle_event("cancel_password_confirmation", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_password_confirmation_modal, false)
     |> assign(:password_confirmation_errors, [])
     |> assign(:pending_password_params, nil)}
  end

  def handle_event("confirm_password_update", params, socket) do
    current_password = Map.get(params, "current_password")
    user_params = socket.assigns.pending_password_params
    user = socket.assigns.current_user

    if user_params == nil do
      {:noreply, assign(socket, show_password_confirmation_modal: false)}
    else
      case Accounts.update_user_password(user, current_password, user_params) do
        {:ok, user} ->
          password_form =
            user
            |> Accounts.change_user_password(user_params)
            |> to_form()

          {:noreply,
           socket
           |> assign(:trigger_submit, true)
           |> assign(:password_form, password_form)
           |> assign(:show_password_confirmation_modal, false)
           |> assign(:pending_password_params, nil)
           |> assign(:password_confirmation_errors, [])}

        {:error, changeset} ->
          current_password_errors =
            changeset.errors
            |> Keyword.get_values(:current_password)
            |> Enum.map(&translate_error/1)

          {:noreply,
           socket
           |> assign(:password_form, to_form(changeset))
           |> assign(:show_password_confirmation_modal, true)
           |> assign(:password_confirmation_errors, current_password_errors)}
      end
    end
  end
end
