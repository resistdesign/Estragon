"""Test-only validation of C01-C metadata evidence, not a production guard."""
import json
import re


def validate_metadata(output, minor):
    prefix = "C01_CALLBACK_METADATA "
    rows = [json.loads(line[len(prefix):]) for line in output.splitlines() if line.startswith(prefix)]
    by_name = {row["name"]: row for row in rows}
    if len(rows) != 20 or len(by_name) != 20:
        raise ValueError("Expected all 20 distinct callable observations")
    # get_method() itself reports an expected native error for opaque lambdas
    # on older engines. No Logger API is required to count exact diagnostics.
    errors = [line for line in output.splitlines()
              if re.search(r"SCRIPT ERROR:|^ERROR:|Parse Error:|Assertion failed:", line)]
    missing = sum(row["valid"] and row["custom"] and not row["method"] for row in rows)
    if len(errors) != missing or any("Can't get method on CallableCustom" not in line or "lambda" not in line for line in errors):
        raise ValueError("Unexpected engine diagnostics in metadata probe: " + repr(errors))
    for left, right in [("lambda_zero", "lambda_required"), ("lambda_zero", "lambda_optional"),
                        ("named_lambda_zero", "named_lambda_required"),
                        ("returned_lambda_zero", "returned_lambda_required")]:
        # Native count is deliberately excluded: this is the 4.0 reflection
        # strategy under consideration, compared against the modern authority.
        observed = lambda row: {key: value for key, value in row.items() if key not in ["name", "native_count"]}
        if observed(by_name[left]) != observed(by_name[right]):
            raise ValueError("Revisit reflection limitation: pair is distinguishable: " + left)
    for row in rows:
        if row["valid"] and row["connect_error"] != 0:
            raise ValueError("Revisit connect-as-validation alternative: " + row["name"])
    if by_name["empty"]["valid"] or by_name["missing"]["valid"]:
        raise ValueError("Invalid callable control was unexpectedly valid")
    counts = {"method_zero": 0, "method_required": 1, "method_optional": 1,
              "method_bound": 0, "method_optional_bound": 0, "method_unbound": 1,
              "static_zero": 0, "lambda_zero": 0, "lambda_captureless": 0,
              "lambda_required": 1, "lambda_optional": 1, "lambda_captured": 0,
              "named_lambda_zero": 0, "named_lambda_required": 1,
              "returned_lambda_zero": 0, "returned_lambda_required": 1,
              "bound_lambda": 0, "unbound_lambda": 1}
    for name, count in counts.items():
        expected = count if minor >= 3 else None
        if by_name[name]["native_count"] != expected:
            raise ValueError("Unexpected native argument-count evidence: " + name)
    return {"observations": rows, "expected_metadata_errors": missing,
            "legacy_reflection_strategy": "BLOCKED",
            "reason": "Zero-, required- and optional-argument lambdas have identical signature-relevant public reflection; signal connect accepts all three.",
            "unchanged_native_count_guard": "UNAVAILABLE" if minor < 3 else "AVAILABLE"}
