"""Validate numeric probe records against independent checked-in byte oracles."""
import json


def validate_numeric(output, fixture):
    def rows(prefix):
        return [json.loads(line[len(prefix):]) for line in output.splitlines() if line.startswith(prefix)]

    cases = rows("C01_NUMERIC_CASE ")
    limits = rows("C01_NUMERIC_NATIVE_LIMIT ")
    for observed, expected, limitation in [(cases, fixture["cases"], False),
                                            (limits, fixture["native_parser_limits"], True)]:
        by_source = {row["source"]: row for row in observed}
        if len(by_source) != len(observed) or set(by_source) != {row["source"] for row in expected}:
            raise ValueError("Missing, duplicated or unexpected numeric observations")
        for item in expected:
            row = by_source[item["source"]]
            if (row["expected_bits"] != item["expected_bits"] or row["storage_bits"] != item["expected_bits"]
                    or not row.get("deterministic_and_mapped")):
                raise ValueError("Invalid numeric oracle or source-map evidence: " + item["source"])
            equal = row["model_bits"] == row["runtime_bits"] == item["expected_bits"]
            wanted = "PASS" if equal else "BLOCKED" if limitation else "FAIL"
            if limitation:
                preserved = row["model_bits"] == row["runtime_bits"] == row["raw_conversion_bits"] == row["direct_literal_bits"]
                if not preserved or row.get("native_value_preserved") is not True:
                    raise ValueError("Emission changed the native parsed value: " + item["source"])
            if row["status"] != wanted:
                raise ValueError("Numeric value mismatch: " + item["source"])
    return {"cases": cases, "native_parser_limits": limits}
