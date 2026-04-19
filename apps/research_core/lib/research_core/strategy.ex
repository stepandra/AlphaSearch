defmodule ResearchCore.Strategy do
  @moduledoc """
  Domain and normalization entrypoints for turning validated synthesis into strategy specs.
  """

  alias ResearchCore.Strategy.{
    CandidateNormalizer,
    DuplicateSuppressor,
    FormulaNormalizer,
    InputBuilder,
    InputPackage,
    StrategySpec,
    Validator
  }

  @spec build_input_package(map(), struct(), struct(), struct(), keyword()) ::
          {:ok, InputPackage.t()} | {:error, term()}
  def build_input_package(bundle, synthesis_run, artifact, validation_result, opts \\ []) do
    InputBuilder.build(bundle, synthesis_run, artifact, validation_result, opts)
  end

  @spec normalize(map(), [map()], [map()], keyword()) ::
          {:ok,
           %{
             formulas: list(),
             candidates: list(),
             specs: [StrategySpec.t()],
             validation: struct()
           }}
          | {:error, term()}
  def normalize(
        %InputPackage{} = input_package,
        raw_formula_candidates,
        raw_strategy_candidates,
        opts \\ []
      ) do
    with %{accepted: formulas, rejected: rejected_formulas} <-
           FormulaNormalizer.normalize(input_package, raw_formula_candidates),
         %{accepted: candidates, rejected: rejected_candidates} <-
           CandidateNormalizer.normalize(input_package, formulas, raw_strategy_candidates),
         %{candidates: deduped_candidates, duplicate_groups: duplicate_groups} <-
           DuplicateSuppressor.collapse(input_package, formulas, candidates, opts),
         specs <- CandidateNormalizer.to_specs(input_package, deduped_candidates, opts),
         validation <-
           Validator.validate(
             formulas,
             specs,
             rejected_formulas,
             rejected_candidates,
             duplicate_groups
           ) do
      {:ok,
       %{
         formulas: formulas,
         candidates: deduped_candidates,
         specs: specs,
         validation: validation
       }}
    end
  end
end
