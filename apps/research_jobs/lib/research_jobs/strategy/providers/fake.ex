defmodule ResearchJobs.Strategy.Providers.Fake do
  @moduledoc """
  Deterministic provider used by tests to emulate structured formula and strategy extraction.
  """

  @behaviour ResearchJobs.Strategy.Provider

  alias ResearchJobs.Strategy.{ProviderError, ProviderResponse}
  alias ResearchJobs.Strategy.Models.{Caster, FormulaExtractionBatch, StrategyExtractionBatch}
  alias ResearchCore.Canonical

  @impl true
  def extract_formulas(request_spec, opts) do
    with {:ok, content} <- fetch_content(opts, :formula_content),
         {:ok, model} <- Caster.cast(FormulaExtractionBatch, content) do
      {:ok,
       %ProviderResponse{
         provider: Keyword.get(opts, :provider, "fake"),
         model: Keyword.get(opts, :model, "fake-model-v1"),
         phase: :formula_extraction,
         content: model,
         request_id: Keyword.get(opts, :formula_request_id, "fake-formula-request"),
         response_id: Keyword.get(opts, :formula_response_id, "fake-formula-response"),
         request_hash: Keyword.get(opts, :formula_request_hash, hash(request_spec)),
         response_hash: Keyword.get(opts, :formula_response_hash, hash(content)),
         metadata: %{phase: "formula_extraction"}
       }}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:error,
         %ProviderError{
           provider: "fake",
           reason: :invalid_fake_formula_output,
           message: "fake formula extraction output failed schema validation",
           details: %{
             errors: Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
           }
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def extract_strategies(request_spec, opts) do
    with {:ok, content} <- fetch_content(opts, :strategy_content),
         content <- hydrate_formula_placeholders(content, request_spec),
         {:ok, model} <- Caster.cast(StrategyExtractionBatch, content) do
      {:ok,
       %ProviderResponse{
         provider: Keyword.get(opts, :provider, "fake"),
         model: Keyword.get(opts, :model, "fake-model-v1"),
         phase: :strategy_extraction,
         content: model,
         request_id: Keyword.get(opts, :strategy_request_id, "fake-strategy-request"),
         response_id: Keyword.get(opts, :strategy_response_id, "fake-strategy-response"),
         request_hash: Keyword.get(opts, :strategy_request_hash, hash(request_spec)),
         response_hash: Keyword.get(opts, :strategy_response_hash, hash(content)),
         metadata: %{phase: "strategy_extraction"}
       }}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:error,
         %ProviderError{
           provider: "fake",
           reason: :invalid_fake_strategy_output,
           message: "fake strategy extraction output failed schema validation",
           details: %{
             errors: Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
           }
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_content(opts, key) do
    case Keyword.get(opts, key) do
      nil ->
        {:error,
         %ProviderError{
           provider: "fake",
           reason: :missing_fake_content,
           message: "fake provider requires #{inspect(key)}",
           details: %{}
         }}

      value ->
        {:ok, value}
    end
  end

  defp hydrate_formula_placeholders(%{strategies: strategies} = content, request_spec)
       when is_list(strategies) do
    formula_ids = Enum.map(Map.get(request_spec, :formulas, []), & &1.id)

    %{content | strategies: Enum.map(strategies, &hydrate_strategy_formula_refs(&1, formula_ids))}
  end

  defp hydrate_formula_placeholders(content, _request_spec), do: content

  defp hydrate_strategy_formula_refs(strategy, [first_formula_id | _]) when is_map(strategy) do
    update_in(strategy, [:formula_references], fn references ->
      references
      |> List.wrap()
      |> Enum.map(fn
        "__FIRST_FORMULA__" -> first_formula_id
        value -> value
      end)
    end)
  end

  defp hydrate_strategy_formula_refs(strategy, _formula_ids), do: strategy

  defp hash(value) do
    Canonical.hash(value)
  end
end
