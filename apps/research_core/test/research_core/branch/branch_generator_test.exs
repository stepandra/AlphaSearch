defmodule ResearchCore.Branch.BranchGeneratorTest do
  use ExUnit.Case, async: true

  alias ResearchCore.Branch.{Branch, BranchGenerator, BranchKind}
  alias ResearchCore.Theme.{Normalized, DomainHint, MechanismHint, Objective, Constraint}

  # -- Helpers --

  defp well_formed_theme do
    %Normalized{
      original_input: "raw input",
      normalized_text: "normalized input",
      topic: "neural plasticity",
      domain_hints: [
        %DomainHint{label: "neuroscience"},
        %DomainHint{label: "cognitive psychology"}
      ],
      mechanism_hints: [
        %MechanismHint{label: "synaptic pruning"},
        %MechanismHint{label: "long-term potentiation"}
      ],
      objective: %Objective{description: "map learning pathways"},
      constraints: [%Constraint{description: "human subjects only", kind: :scope}]
    }
  end

  defp minimal_theme do
    %Normalized{
      original_input: "raw",
      normalized_text: "normalized",
      topic: "entropy"
    }
  end

  # -- Core contract --

  describe "generate/1 with a well-formed theme" do
    setup do
      %{branches: BranchGenerator.generate(well_formed_theme())}
    end

    test "returns exactly 6 branches", %{branches: branches} do
      assert length(branches) == 6
    end

    test "returns all branch kinds in canonical order", %{branches: branches} do
      kinds = Enum.map(branches, & &1.kind)
      assert kinds == BranchKind.all()
    end

    test "every branch is a Branch struct", %{branches: branches} do
      assert Enum.all?(branches, &match?(%Branch{}, &1))
    end

    test "every branch has non-empty label, rationale, and theme_relation", %{branches: branches} do
      for branch <- branches do
        assert is_binary(branch.label) and branch.label != ""
        assert is_binary(branch.rationale) and branch.rationale != ""
        assert is_binary(branch.theme_relation) and branch.theme_relation != ""
      end
    end

    test "every branch has empty query_families", %{branches: branches} do
      for branch <- branches do
        assert branch.query_families == []
      end
    end
  end

  # -- Deterministic output --

  describe "determinism" do
    test "calling generate/1 twice on the same input produces identical output" do
      theme = well_formed_theme()
      assert BranchGenerator.generate(theme) == BranchGenerator.generate(theme)
    end
  end

  # -- Individual branch kinds --

  describe "direct branch" do
    test "label is the topic verbatim" do
      [direct | _] = BranchGenerator.generate(well_formed_theme())
      assert direct.kind == :direct
      assert direct.label == "neural plasticity"
      assert direct.theme_relation == "verbatim"
    end
  end

  describe "narrower branch" do
    test "incorporates first domain hint when present" do
      branches = BranchGenerator.generate(well_formed_theme())
      narrower = Enum.find(branches, &(&1.kind == :narrower))
      assert narrower.label =~ "neuroscience"
      assert narrower.theme_relation == "subset"
    end

    test "falls back to objective when no domain hints" do
      theme = %Normalized{
        original_input: "raw",
        normalized_text: "norm",
        topic: "entropy",
        objective: %Objective{description: "measure disorder"}
      }

      narrower = BranchGenerator.generate(theme) |> Enum.find(&(&1.kind == :narrower))
      assert narrower.label =~ "measure disorder"
    end

    test "falls back to constraint when no domain hints or objective" do
      theme = %Normalized{
        original_input: "raw",
        normalized_text: "norm",
        topic: "entropy",
        constraints: [%Constraint{description: "thermodynamic systems", kind: :scope}]
      }

      narrower = BranchGenerator.generate(theme) |> Enum.find(&(&1.kind == :narrower))
      assert narrower.label =~ "thermodynamic systems"
    end

    test "uses default qualifier when theme is minimal" do
      narrower = BranchGenerator.generate(minimal_theme()) |> Enum.find(&(&1.kind == :narrower))
      assert narrower.label =~ "specific aspects"
    end
  end

  describe "broader branch" do
    test "incorporates first domain hint when present" do
      broader = BranchGenerator.generate(well_formed_theme()) |> Enum.find(&(&1.kind == :broader))
      assert broader.label =~ "neuroscience"
      assert broader.label =~ "neural plasticity"
      assert broader.theme_relation == "superset"
    end

    test "uses general context for minimal theme" do
      broader = BranchGenerator.generate(minimal_theme()) |> Enum.find(&(&1.kind == :broader))
      assert broader.label =~ "general context of entropy"
    end
  end

  describe "analog branch" do
    test "uses second domain hint when two or more present" do
      analog = BranchGenerator.generate(well_formed_theme()) |> Enum.find(&(&1.kind == :analog))
      assert analog.label =~ "cognitive psychology"
      assert analog.theme_relation == "analogy"
    end

    test "falls back to first mechanism hint with one domain hint" do
      theme = %Normalized{
        original_input: "raw",
        normalized_text: "norm",
        topic: "entropy",
        domain_hints: [%DomainHint{label: "thermodynamics"}],
        mechanism_hints: [%MechanismHint{label: "heat transfer"}]
      }

      analog = BranchGenerator.generate(theme) |> Enum.find(&(&1.kind == :analog))
      assert analog.label =~ "heat transfer"
    end

    test "uses cross-domain for minimal theme" do
      analog = BranchGenerator.generate(minimal_theme()) |> Enum.find(&(&1.kind == :analog))
      assert analog.label =~ "cross-domain"
    end
  end

  describe "mechanism branch" do
    test "uses first mechanism hint when present" do
      mechanism =
        BranchGenerator.generate(well_formed_theme()) |> Enum.find(&(&1.kind == :mechanism))

      assert mechanism.label =~ "synaptic pruning"
      assert mechanism.theme_relation == "mechanism"
    end

    test "falls back to objective when no mechanism hints" do
      theme = %Normalized{
        original_input: "raw",
        normalized_text: "norm",
        topic: "entropy",
        objective: %Objective{description: "measure disorder"}
      }

      mechanism = BranchGenerator.generate(theme) |> Enum.find(&(&1.kind == :mechanism))
      assert mechanism.label =~ "mechanisms of measure disorder"
    end

    test "uses default for minimal theme" do
      mechanism = BranchGenerator.generate(minimal_theme()) |> Enum.find(&(&1.kind == :mechanism))
      assert mechanism.label =~ "underlying mechanisms"
    end
  end

  describe "method branch" do
    test "uses second mechanism hint when two or more present" do
      method = BranchGenerator.generate(well_formed_theme()) |> Enum.find(&(&1.kind == :method))
      assert method.label =~ "long-term potentiation"
      assert method.theme_relation == "methodology"
    end

    test "falls back to constraint with one mechanism hint" do
      theme = %Normalized{
        original_input: "raw",
        normalized_text: "norm",
        topic: "entropy",
        mechanism_hints: [%MechanismHint{label: "heat transfer"}],
        constraints: [%Constraint{description: "closed systems", kind: :scope}]
      }

      method = BranchGenerator.generate(theme) |> Enum.find(&(&1.kind == :method))
      assert method.label =~ "methods constrained by closed systems"
    end

    test "uses default for minimal theme" do
      method = BranchGenerator.generate(minimal_theme()) |> Enum.find(&(&1.kind == :method))
      assert method.label =~ "analytical methods"
    end
  end

  # -- Edge cases --

  describe "edge cases" do
    test "handles nil objective and notes gracefully" do
      theme = %Normalized{
        original_input: "raw",
        normalized_text: "norm",
        topic: "test topic",
        objective: nil,
        notes: nil
      }

      branches = BranchGenerator.generate(theme)
      assert length(branches) == 6
      assert Enum.all?(branches, &match?(%Branch{}, &1))
    end

    test "handles empty lists for domain_hints, mechanism_hints, constraints" do
      branches = BranchGenerator.generate(minimal_theme())
      assert length(branches) == 6
    end

    test "single-word topic still produces valid branches" do
      theme = %Normalized{
        original_input: "x",
        normalized_text: "x",
        topic: "x"
      }

      branches = BranchGenerator.generate(theme)
      assert length(branches) == 6

      for branch <- branches do
        assert String.length(branch.label) > 0
      end
    end
  end
end
